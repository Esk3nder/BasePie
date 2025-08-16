// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IBatchRebalancer} from "./interfaces/IBatchRebalancer.sol";
import {IPieVault} from "./interfaces/IPieVault.sol";
import {IOracleModule} from "./interfaces/IOracleModule.sol";
import {ITradeAdapter} from "./interfaces/ITradeAdapter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract BatchRebalancer is IBatchRebalancer, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    // Roles
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    
    // Constants
    uint256 public constant MAX_BPS = 10_000;
    uint256 public constant PRECISION = 1e18;
    uint8 public constant USDC_DECIMALS = 6;
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    
    // Dependencies
    IOracleModule public oracleModule;
    ITradeAdapter public tradeAdapter;
    
    // State
    mapping(address => uint40) public lastProcessedWindow;
    
    constructor(address _oracleModule, address _tradeAdapter) {
        oracleModule = IOracleModule(_oracleModule);
        tradeAdapter = ITradeAdapter(_tradeAdapter);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GOVERNOR_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);
    }
    
    function processWindow(address pie) external nonReentrant onlyRole(KEEPER_ROLE) {
        IPieVault vault = IPieVault(pie);
        uint40 windowId = vault.getCurrentWindowId();
        
        require(lastProcessedWindow[pie] < windowId, "Window already processed");
        
        uint256 gasStart = gasleft();
        
        uint256 navPre = computePortfolioNav(pie);
        
        uint256[] memory requestIds = vault.getPendingRequests(windowId);
        
        (address[] memory tokens, int256[] memory deltas,) = computeRebalanceDeltas(pie);
        
        uint256[] memory actualAmounts = _executeTrades(pie, tokens, deltas);
        
        uint256[] memory executedAmounts = new uint256[](requestIds.length);
        uint256 totalDeposits;
        uint256 totalRedeems;
        
        for (uint256 i = 0; i < requestIds.length; i++) {
            IPieVault.Request memory req = vault.getRequest(requestIds[i]);
            if (req.kind == IPieVault.RequestKind.Deposit) {
                totalDeposits += req.amount;
            } else {
                totalRedeems += req.amount;
            }
        }
        
        if (totalDeposits > 0) {
            uint256 totalSupply = vault.totalSupply();
            uint256 sharesToMint = totalSupply == 0 ? 
                totalDeposits * PRECISION / 10 ** USDC_DECIMALS : 
                (totalDeposits * totalSupply) / navPre;
                
            for (uint256 i = 0; i < requestIds.length; i++) {
                IPieVault.Request memory req = vault.getRequest(requestIds[i]);
                if (req.kind == IPieVault.RequestKind.Deposit) {
                    executedAmounts[i] = (sharesToMint * req.amount) / totalDeposits;
                }
            }
        }
        
        if (totalRedeems > 0) {
            uint256 assetsForRedeems = (navPre * totalRedeems) / vault.totalSupply();
            
            for (uint256 i = 0; i < requestIds.length; i++) {
                IPieVault.Request memory req = vault.getRequest(requestIds[i]);
                if (req.kind == IPieVault.RequestKind.Redeem) {
                    executedAmounts[i] = (assetsForRedeems * req.amount) / totalRedeems;
                }
            }
        }
        
        uint256 navPost = computePortfolioNav(pie);
        
        IPieVault.SettlementData memory data = IPieVault.SettlementData({
            navPreUsd: navPre,
            navPostUsd: navPost,
            requestIds: requestIds,
            executedAmounts: executedAmounts,
            tradeData: ""
        });
        
        vault.settleWindow(windowId, data);
        
        lastProcessedWindow[pie] = windowId;
        
        uint256 gasUsed = gasStart - gasleft();
        emit WindowProcessed(windowId, pie, navPre, navPost, gasUsed);
    }
    
    function computePortfolioNav(address pie) public view returns (uint256 navUsdE18) {
        IPieVault vault = IPieVault(pie);
        (address[] memory tokens,) = vault.getSlices();
        
        navUsdE18 = 0;
        
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 balance;
            
            if (tokens[i] == USDC) {
                balance = IERC20(USDC).balanceOf(pie);
                navUsdE18 += balance * 10**12;
            } else {
                balance = IERC20(tokens[i]).balanceOf(pie);
                
                (uint256 priceE18,,) = oracleModule.getUsdPrice(tokens[i]);
                
                navUsdE18 += (balance * priceE18) / PRECISION;
            }
        }
        
        return navUsdE18;
    }
    
    function computeRebalanceDeltas(address pie) 
        public 
        returns (
            address[] memory tokens,
            int256[] memory deltas,
            uint256 navUsdE18
        ) 
    {
        IPieVault vault = IPieVault(pie);
        uint16[] memory weights;
        (tokens, weights) = vault.getSlices();
        
        navUsdE18 = computePortfolioNav(pie);
        deltas = new int256[](tokens.length);
        
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 targetValueE18 = (navUsdE18 * weights[i]) / MAX_BPS;
            
            uint256 currentValueE18;
            uint256 balance = IERC20(tokens[i]).balanceOf(pie);
            
            if (tokens[i] == USDC) {
                currentValueE18 = balance * 10**12;
            } else {
                (uint256 priceE18,,) = oracleModule.getUsdPrice(tokens[i]);
                currentValueE18 = (balance * priceE18) / PRECISION;
            }
            
            deltas[i] = int256(targetValueE18) - int256(currentValueE18);
            
            uint256 maxTradeValue = (navUsdE18 * vault.maxTradeBpsPerWindow()) / MAX_BPS;
            if (deltas[i] > 0 && uint256(deltas[i]) > maxTradeValue) {
                deltas[i] = int256(maxTradeValue);
            } else if (deltas[i] < 0 && uint256(-deltas[i]) > maxTradeValue) {
                deltas[i] = -int256(maxTradeValue);
            }
            
            // emit DeltaComputed(tokens[i], deltas[i], currentValueE18, targetValueE18);
        }
        
        return (tokens, deltas, navUsdE18);
    }
    
    function _executeTrades(
        address pie,
        address[] memory tokens,
        int256[] memory deltas
    ) internal returns (uint256[] memory actualAmounts) {
        actualAmounts = new uint256[](tokens.length);
        IPieVault vault = IPieVault(pie);
        uint256 slippageBps = vault.slippageBps();
        
        for (uint256 i = 0; i < tokens.length; i++) {
            if (deltas[i] < 0 && tokens[i] != USDC) {
                uint256 sellAmount = uint256(-deltas[i]);
                
                (uint256 priceE18,,) = oracleModule.getUsdPrice(tokens[i]);
                uint256 tokenAmount = (sellAmount * PRECISION) / priceE18;
                
                uint256 minUsdcOut = (sellAmount * (MAX_BPS - slippageBps)) / MAX_BPS;
                minUsdcOut = minUsdcOut / 10**12;
                
                IERC20(tokens[i]).safeTransferFrom(pie, address(this), tokenAmount);
                
                IERC20(tokens[i]).approve(address(tradeAdapter), 0);
                IERC20(tokens[i]).approve(address(tradeAdapter), tokenAmount);
                
                uint256 usdcReceived = tradeAdapter.executeTrade(
                    tokens[i],
                    USDC,
                    tokenAmount,
                    minUsdcOut
                );
                
                IERC20(USDC).safeTransfer(pie, usdcReceived);
                
                actualAmounts[i] = usdcReceived;
                emit TradeExecuted(tokens[i], USDC, tokenAmount, usdcReceived);
            }
        }
        
        for (uint256 i = 0; i < tokens.length; i++) {
            if (deltas[i] > 0 && tokens[i] != USDC) {
                uint256 buyAmount = uint256(deltas[i]);
                uint256 usdcAmount = buyAmount / 10**12;
                
                (uint256 priceE18,,) = oracleModule.getUsdPrice(tokens[i]);
                uint256 expectedTokens = (buyAmount * PRECISION) / priceE18;
                uint256 minTokensOut = (expectedTokens * (MAX_BPS - slippageBps)) / MAX_BPS;
                
                IERC20(USDC).safeTransferFrom(pie, address(this), usdcAmount);
                
                IERC20(USDC).approve(address(tradeAdapter), 0);
                IERC20(USDC).approve(address(tradeAdapter), usdcAmount);
                
                uint256 tokensReceived = tradeAdapter.executeTrade(
                    USDC,
                    tokens[i],
                    usdcAmount,
                    minTokensOut
                );
                
                IERC20(tokens[i]).safeTransfer(pie, tokensReceived);
                
                actualAmounts[i] = tokensReceived;
                emit TradeExecuted(USDC, tokens[i], usdcAmount, tokensReceived);
            }
        }
        
        return actualAmounts;
    }
    
    function _processDepositRequests(
        IPieVault vault,
        uint256[] memory requestIds,
        uint256 navPre
    ) internal returns (uint256[] memory sharesMinted) {
        sharesMinted = new uint256[](requestIds.length);
        uint256 totalDeposits;
        
        for (uint256 i = 0; i < requestIds.length; i++) {
            IPieVault.Request memory req = vault.getRequest(requestIds[i]);
            if (req.kind == IPieVault.RequestKind.Deposit) {
                totalDeposits += req.amount;
            }
        }
        
        if (totalDeposits > 0) {
            uint256 totalSupply = vault.totalSupply();
            uint256 totalShares = totalSupply == 0 ? 
                totalDeposits * PRECISION / 10 ** USDC_DECIMALS : 
                (totalDeposits * totalSupply) / navPre;
                
            for (uint256 i = 0; i < requestIds.length; i++) {
                IPieVault.Request memory req = vault.getRequest(requestIds[i]);
                if (req.kind == IPieVault.RequestKind.Deposit) {
                    sharesMinted[i] = (totalShares * req.amount) / totalDeposits;
                }
            }
        }
        
        return sharesMinted;
    }
    
    function _processRedeemRequests(
        IPieVault vault,
        uint256[] memory requestIds,
        uint256 navPre
    ) internal returns (uint256[] memory assetsOut) {
        assetsOut = new uint256[](requestIds.length);
        uint256 totalRedeems;
        
        for (uint256 i = 0; i < requestIds.length; i++) {
            IPieVault.Request memory req = vault.getRequest(requestIds[i]);
            if (req.kind == IPieVault.RequestKind.Redeem) {
                totalRedeems += req.amount;
            }
        }
        
        if (totalRedeems > 0) {
            uint256 totalAssets = (navPre * totalRedeems) / vault.totalSupply();
            
            for (uint256 i = 0; i < requestIds.length; i++) {
                IPieVault.Request memory req = vault.getRequest(requestIds[i]);
                if (req.kind == IPieVault.RequestKind.Redeem) {
                    assetsOut[i] = (totalAssets * req.amount) / totalRedeems;
                }
            }
        }
        
        return assetsOut;
    }
    
    // Admin functions
    function setOracleModule(address _oracleModule) external onlyRole(GOVERNOR_ROLE) {
        require(_oracleModule != address(0), "Invalid oracle");
        oracleModule = IOracleModule(_oracleModule);
    }
    
    function setTradeAdapter(address _tradeAdapter) external onlyRole(GOVERNOR_ROLE) {
        require(_tradeAdapter != address(0), "Invalid adapter");
        tradeAdapter = ITradeAdapter(_tradeAdapter);
    }
}