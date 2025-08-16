// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPieVault} from "./interfaces/IPieVault.sol";
import {RequestLib} from "./libraries/RequestLib.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract PieVault is 
    Initializable,
    ERC4626,
    AccessControl,
    Pausable,
    ReentrancyGuard,
    IPieVault
{
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    // Roles
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    bytes32 public constant REBALANCER_ROLE = keccak256("REBALANCER_ROLE");
    
    // Constants
    uint16 public constant MAX_BPS = 10_000;
    uint256 public constant WINDOW_DURATION = 1 days;
    uint8 public constant USDC_DECIMALS = 6;
    
    // State - Portfolio
    address[] public sliceTokens;
    mapping(address => uint16) public tokenWeights;
    mapping(address => uint256) public tokenBalances;
    
    // State - Requests
    uint256 public nextRequestId;
    mapping(uint256 => Request) public requests;
    mapping(uint40 => uint256[]) public windowRequests;
    
    // State - Windows
    uint40 public currentWindowId;
    uint256 public windowStartTimestamp;
    uint256 public rebalanceWindowStartSecUTC;
    
    // State - Parameters
    uint16 public mgmtFeeBps;
    uint16 public slippageBps;
    uint16 public maxTradeBpsPerWindow;
    address public feeReceiver;
    
    // State - Accounting
    uint256 public lastNavUsdE18;
    uint256 public lastSettlementBlock;
    
    // Pending weights for next window
    address[] public pendingTokens;
    uint16[] public pendingWeights;
    bool public hasPendingWeights;
    
    constructor() ERC4626(IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913)) ERC20("", "") {
        _disableInitializers();
    }
    
    // INITIALIZATION
    
    function initialize(
        string memory name,
        string memory symbol,
        address[] memory assets,
        uint16[] memory weightsBps,
        address creator,
        address _feeReceiver,
        uint16 _mgmtFeeBps,
        uint32 _rebalanceWindowStartSecUTC
    ) external initializer {
        require(assets.length > 0, "No assets");
        require(assets.length == weightsBps.length, "Length mismatch");
        
        // Validate weights sum to 10000
        uint256 totalWeight;
        for (uint256 i = 0; i < weightsBps.length; i++) {
            totalWeight += weightsBps[i];
            sliceTokens.push(assets[i]);
            tokenWeights[assets[i]] = weightsBps[i];
        }
        require(totalWeight == MAX_BPS, "Invalid weights");
        
        // Initialize ERC20 metadata (handled by parent constructor)
        // Note: ERC4626 handles name/symbol internally
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CREATOR_ROLE, creator);
        _grantRole(REBALANCER_ROLE, msg.sender); // Factory is initial rebalancer
        
        // Set parameters
        feeReceiver = _feeReceiver;
        mgmtFeeBps = _mgmtFeeBps;
        rebalanceWindowStartSecUTC = _rebalanceWindowStartSecUTC;
        windowStartTimestamp = block.timestamp;
        
        // Initialize NAV to 0 (no assets yet)
        lastNavUsdE18 = 0;
        
        // Default parameters
        slippageBps = 50; // 0.5%
        maxTradeBpsPerWindow = 1500; // 15%
    }
    
    // ASYNC REQUEST FUNCTIONS
    
    function requestDeposit(uint256 assets, address receiver) 
        external 
        whenNotPaused 
        nonReentrant 
        returns (uint256 requestId) 
    {
        require(assets > 0, "Zero assets");
        require(receiver != address(0), "Zero receiver");
        
        // Transfer USDC from sender
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), assets);
        
        // Create request
        requestId = nextRequestId++;
        uint40 targetWindow = _getCurrentWindowId() + 1; // Next window
        
        requests[requestId] = Request({
            owner: msg.sender,
            receiver: receiver,
            amount: uint128(assets),
            executedAmount: 0,
            windowId: targetWindow,
            kind: RequestKind.Deposit,
            status: RequestStatus.Pending
        });
        
        // Add to window queue
        windowRequests[targetWindow].push(requestId);
        
        emit DepositRequested(requestId, msg.sender, receiver, assets);
    }
    
    function requestRedeem(uint256 shares, address receiver) 
        external 
        whenNotPaused 
        nonReentrant 
        returns (uint256 requestId) 
    {
        require(shares > 0, "Zero shares");
        require(shares <= balanceOf(msg.sender), "Insufficient shares");
        require(receiver != address(0), "Zero receiver");
        
        // Transfer shares from sender to vault
        _transfer(msg.sender, address(this), shares);
        
        // Create request
        requestId = nextRequestId++;
        uint40 targetWindow = _getCurrentWindowId() + 1; // Next window
        
        requests[requestId] = Request({
            owner: msg.sender,
            receiver: receiver,
            amount: uint128(shares),
            executedAmount: 0,
            windowId: targetWindow,
            kind: RequestKind.Redeem,
            status: RequestStatus.Pending
        });
        
        // Add to window queue
        windowRequests[targetWindow].push(requestId);
        
        emit RedeemRequested(requestId, msg.sender, receiver, shares);
    }
    
    function claim(uint256 requestId) 
        external 
        nonReentrant 
        returns (uint256 amount) 
    {
        Request storage request = requests[requestId];
        RequestLib.validateClaim(request, msg.sender);
        
        amount = request.executedAmount;
        RequestLib.transitionStatus(request, RequestStatus.Claimed);
        
        if (request.kind == RequestKind.Deposit) {
            // Transfer shares for deposit
            _transfer(address(this), request.receiver, amount);
            emit DepositClaimed(requestId, request.receiver, amount);
        } else {
            // Transfer USDC for redeem
            IERC20(asset()).safeTransfer(request.receiver, amount);
            emit RedeemClaimed(requestId, request.receiver, amount);
        }
    }
    
    function cancel(uint256 requestId) 
        external 
        nonReentrant 
    {
        Request storage request = requests[requestId];
        RequestLib.validateCancel(request, msg.sender);
        
        uint256 refundAmount = request.amount;
        RequestLib.transitionStatus(request, RequestStatus.Cancelled);
        
        // Remove from window queue
        _removeFromWindowQueue(request.windowId, requestId);
        
        if (request.kind == RequestKind.Deposit) {
            // Refund USDC
            IERC20(asset()).safeTransfer(request.owner, refundAmount);
            emit DepositCancelled(requestId, request.owner, refundAmount);
        } else {
            // Refund shares
            _transfer(address(this), request.owner, refundAmount);
            emit RedeemCancelled(requestId, request.owner, refundAmount);
        }
    }
    
    function claimBatch(uint256[] calldata requestIds) 
        external 
        nonReentrant 
        returns (uint256[] memory amounts) 
    {
        amounts = new uint256[](requestIds.length);
        for (uint256 i = 0; i < requestIds.length; i++) {
            Request storage request = requests[requestIds[i]];
            if (request.status == RequestStatus.Executed && 
                (msg.sender == request.receiver || msg.sender == request.owner)) {
                amounts[i] = request.executedAmount;
                RequestLib.transitionStatus(request, RequestStatus.Claimed);
                
                if (request.kind == RequestKind.Deposit) {
                    _transfer(address(this), request.receiver, amounts[i]);
                    emit DepositClaimed(requestIds[i], request.receiver, amounts[i]);
                } else {
                    IERC20(asset()).safeTransfer(request.receiver, amounts[i]);
                    emit RedeemClaimed(requestIds[i], request.receiver, amounts[i]);
                }
            }
        }
    }
    
    // SETTLEMENT
    
    function settleWindow(uint40 windowId, SettlementData calldata data) 
        external 
        onlyRole(REBALANCER_ROLE) 
        nonReentrant 
    {
        require(windowId == _getCurrentWindowId(), "Invalid window");
        require(block.number > lastSettlementBlock, "Already settled");
        
        uint256[] memory pendingRequestIds = windowRequests[windowId];
        require(pendingRequestIds.length == data.requestIds.length, "Request mismatch");
        
        uint256 totalDepositAssets;
        uint256 totalRedeemShares;
        
        // Process requests
        for (uint256 i = 0; i < data.requestIds.length; i++) {
            Request storage request = requests[data.requestIds[i]];
            RequestLib.validateExecution(request, windowId);
            
            if (request.kind == RequestKind.Deposit) {
                totalDepositAssets += request.amount;
            } else {
                totalRedeemShares += request.amount;
            }
            
            request.executedAmount = uint128(data.executedAmounts[i]);
            RequestLib.transitionStatus(request, RequestStatus.Executed);
            
            if (request.kind == RequestKind.Deposit) {
                emit DepositExecuted(data.requestIds[i], request.amount, data.executedAmounts[i]);
            } else {
                emit RedeemExecuted(data.requestIds[i], request.amount, data.executedAmounts[i]);
            }
        }
        
        // Mint shares for deposits
        if (totalDepositAssets > 0) {
            uint256 sharesToMint = RequestLib.calculateSharesForDeposit(
                totalDepositAssets,
                totalSupply(),
                data.navPreUsd
            );
            _mint(address(this), sharesToMint);
        }
        
        // Burn shares for redeems
        if (totalRedeemShares > 0) {
            _burn(address(this), totalRedeemShares);
        }
        
        // Apply pending weights if scheduled
        if (hasPendingWeights) {
            delete sliceTokens;
            for (uint256 i = 0; i < pendingTokens.length; i++) {
                sliceTokens.push(pendingTokens[i]);
                tokenWeights[pendingTokens[i]] = pendingWeights[i];
            }
            delete pendingTokens;
            delete pendingWeights;
            hasPendingWeights = false;
        }
        
        // Update accounting
        lastNavUsdE18 = data.navPostUsd;
        lastSettlementBlock = block.number;
        currentWindowId = windowId + 1;
        
        emit WindowSettled(windowId, data.navPreUsd, data.navPostUsd, pendingRequestIds.length);
    }
    
    // ADMIN FUNCTIONS
    
    function scheduleWeights(address[] calldata tokens, uint16[] calldata weightsBps) 
        external 
        onlyRole(CREATOR_ROLE) 
    {
        require(tokens.length > 0, "No tokens");
        require(tokens.length == weightsBps.length, "Length mismatch");
        
        uint256 totalWeight;
        for (uint256 i = 0; i < weightsBps.length; i++) {
            totalWeight += weightsBps[i];
        }
        require(totalWeight == MAX_BPS, "Invalid weights");
        
        // Store as pending
        delete pendingTokens;
        delete pendingWeights;
        
        for (uint256 i = 0; i < tokens.length; i++) {
            pendingTokens.push(tokens[i]);
            pendingWeights.push(weightsBps[i]);
        }
        
        hasPendingWeights = true;
        uint40 effectiveWindow = _getCurrentWindowId() + 1;
        
        emit WeightsUpdated(tokens, weightsBps, effectiveWindow);
    }
    
    function setParams(uint16 _slippageBps, uint16 _maxTradeBpsPerWindow) 
        external 
        onlyRole(CREATOR_ROLE) 
    {
        require(_slippageBps <= 500, "Slippage too high"); // Max 5%
        require(_maxTradeBpsPerWindow <= 5000, "Trade limit too high"); // Max 50%
        
        slippageBps = _slippageBps;
        maxTradeBpsPerWindow = _maxTradeBpsPerWindow;
        
        emit ParamsUpdated(_slippageBps, _maxTradeBpsPerWindow);
    }
    
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    // VIEW FUNCTIONS - Portfolio
    
    function getSlices() external view returns (address[] memory tokens, uint16[] memory weightsBps) {
        tokens = sliceTokens;
        weightsBps = new uint16[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            weightsBps[i] = tokenWeights[tokens[i]];
        }
    }
    
    function getRequest(uint256 requestId) external view returns (Request memory) {
        return requests[requestId];
    }
    
    function getPendingRequests(uint40 windowId) external view returns (uint256[] memory) {
        return windowRequests[windowId];
    }
    
    function getCurrentWindowId() external view returns (uint40) {
        return _getCurrentWindowId();
    }
    
    function getNextWindowTimestamp() external view returns (uint256) {
        uint256 currentWindow = _getCurrentWindowId();
        return windowStartTimestamp + ((currentWindow + 1) * WINDOW_DURATION);
    }
    
    // VIEW FUNCTIONS - ERC4626 Overrides
    
    function totalAssets() public view override(ERC4626, IERC4626) returns (uint256) {
        // Return NAV in USDC decimals (6)
        // Convert from 18 decimals to 6 decimals
        if (lastNavUsdE18 == 0) {
            return IERC20(asset()).balanceOf(address(this));
        }
        return lastNavUsdE18 / 1e12; // Convert 18 decimals to 6
    }
    
    function convertToShares(uint256 assets) public view override(ERC4626, IERC4626) returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) {
            return assets * 1e12; // Scale from USDC (6) to shares (18)
        }
        return (assets * supply) / totalAssets();
    }
    
    function convertToAssets(uint256 shares) public view override(ERC4626, IERC4626) returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) {
            return 0;
        }
        return (shares * totalAssets()) / supply;
    }
    
    function maxDeposit(address) public view override(ERC4626, IERC4626) returns (uint256) {
        // Async vault - no direct deposits
        return 0;
    }
    
    function maxMint(address) public view override(ERC4626, IERC4626) returns (uint256) {
        // Async vault - no direct mints
        return 0;
    }
    
    function maxWithdraw(address owner) public view override(ERC4626, IERC4626) returns (uint256) {
        // Async vault - no direct withdrawals
        return 0;
    }
    
    function maxRedeem(address owner) public view override(ERC4626, IERC4626) returns (uint256) {
        // Async vault - no direct redeems
        return 0;
    }
    
    function deposit(uint256, address) public override(ERC4626, IERC4626) returns (uint256) {
        revert("Use requestDeposit instead");
    }
    
    function mint(uint256, address) public override(ERC4626, IERC4626) returns (uint256) {
        revert("Use requestDeposit instead");
    }
    
    function withdraw(uint256, address, address) public override(ERC4626, IERC4626) returns (uint256) {
        revert("Use requestRedeem instead");
    }
    
    function redeem(uint256, address, address) public override(ERC4626, IERC4626) returns (uint256) {
        revert("Use requestRedeem instead");
    }
    
    // Override asset() to return USDC address
    function asset() public pure override(ERC4626, IERC4626) returns (address) {
        // Base mainnet USDC
        return 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    }
    
    // Internal helper functions
    function _getCurrentWindowId() internal view returns (uint40) {
        if (block.timestamp < windowStartTimestamp) {
            return 0;
        }
        return uint40((block.timestamp - windowStartTimestamp) / WINDOW_DURATION);
    }
    
    function _removeFromWindowQueue(uint40 windowId, uint256 requestId) internal {
        uint256[] storage queue = windowRequests[windowId];
        for (uint256 i = 0; i < queue.length; i++) {
            if (queue[i] == requestId) {
                queue[i] = queue[queue.length - 1];
                queue.pop();
                break;
            }
        }
    }
}