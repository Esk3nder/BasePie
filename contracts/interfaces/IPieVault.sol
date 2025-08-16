// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

interface IPieVault is IERC20, IERC4626 {
    // Enums
    enum RequestStatus { None, Pending, Executed, Cancelled, Claimed }
    enum RequestKind { Deposit, Redeem }
    
    // Structs
    struct Request {
        address owner;
        address receiver;
        uint128 amount;          // assets for deposit, shares for redeem
        uint128 executedAmount;  // shares minted or assets out
        uint40 windowId;
        RequestKind kind;
        RequestStatus status;
    }
    
    struct SettlementData {
        uint256 navPreUsd;
        uint256 navPostUsd;
        uint256[] requestIds;
        uint256[] executedAmounts;
        bytes tradeData;
    }
    
    // Events - Async Requests
    event DepositRequested(uint256 indexed requestId, address indexed owner, address receiver, uint256 assets);
    event DepositExecuted(uint256 indexed requestId, uint256 assetsIn, uint256 sharesMinted);
    event DepositClaimed(uint256 indexed requestId, address indexed receiver, uint256 shares);
    event DepositCancelled(uint256 indexed requestId, address indexed owner, uint256 assetsReturned);
    
    event RedeemRequested(uint256 indexed requestId, address indexed owner, address receiver, uint256 shares);
    event RedeemExecuted(uint256 indexed requestId, uint256 sharesBurned, uint256 assetsOut);
    event RedeemClaimed(uint256 indexed requestId, address indexed receiver, uint256 assets);
    event RedeemCancelled(uint256 indexed requestId, address indexed owner, uint256 sharesReturned);
    
    // Events - Admin
    event WeightsUpdated(address[] tokens, uint16[] weightsBps, uint40 effectiveWindowId);
    event ParamsUpdated(uint16 slippageBps, uint16 maxTradeBpsPerWindow);
    event WindowSettled(uint40 indexed windowId, uint256 navPre, uint256 navPost, uint256 requestsProcessed);
    
    // Initialization
    function initialize(
        string memory name,
        string memory symbol,
        address[] memory assets,
        uint16[] memory weightsBps,
        address creator,
        address feeReceiver,
        uint16 mgmtFeeBps,
        uint32 rebalanceWindowStartSecUTC
    ) external;
    
    // Async Request Functions
    function requestDeposit(uint256 assets, address receiver) external returns (uint256 requestId);
    function requestRedeem(uint256 shares, address receiver) external returns (uint256 requestId);
    function claim(uint256 requestId) external returns (uint256 amount);
    function cancel(uint256 requestId) external;
    function claimBatch(uint256[] calldata requestIds) external returns (uint256[] memory amounts);
    
    // Settlement (only BatchRebalancer)
    function settleWindow(uint40 windowId, SettlementData calldata data) external;
    
    // Admin Functions
    function scheduleWeights(address[] calldata tokens, uint16[] calldata weightsBps) external;
    function setParams(uint16 slippageBps, uint16 maxTradeBpsPerWindow) external;
    function pause() external;
    function unpause() external;
    
    // View Functions - Portfolio
    function getSlices() external view returns (address[] memory tokens, uint16[] memory weightsBps);
    function getRequest(uint256 requestId) external view returns (Request memory);
    function getPendingRequests(uint40 windowId) external view returns (uint256[] memory);
    function getCurrentWindowId() external view returns (uint40);
    function getNextWindowTimestamp() external view returns (uint256);
    
    // View Functions - Accounting
    function lastNavUsdE18() external view returns (uint256);
    function mgmtFeeBps() external view returns (uint16);
    function slippageBps() external view returns (uint16);
    function maxTradeBpsPerWindow() external view returns (uint16);
}