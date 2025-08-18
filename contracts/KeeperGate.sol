// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IKeeperGate} from "./interfaces/IKeeperGate.sol";
import {IPieVault} from "./interfaces/IPieVault.sol";
import {IBatchRebalancer} from "./interfaces/IBatchRebalancer.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title KeeperGate
 * @notice Manages rebalancing window lifecycle for pie portfolios
 * @dev Enforces timing constraints and access control for automated rebalancing
 */
contract KeeperGate is IKeeperGate, AccessControl, Pausable, ReentrancyGuard {
    // Roles
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER");
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR");
    
    // Constants
    uint32 public constant WINDOW_TOLERANCE = 300; // 5 minutes in seconds
    uint32 public constant DEFAULT_GRACE_PERIOD = 1800; // 30 minutes
    
    // State
    IBatchRebalancer public immutable rebalancer;
    uint32 public gracePeriod;
    mapping(address => uint40) public lastProcessedWindow;
    
    /**
     * @notice Constructor
     * @param _rebalancer Address of the BatchRebalancer contract
     * @param _admin Address to grant admin roles
     */
    constructor(address _rebalancer, address _admin) {
        require(_rebalancer != address(0), "Invalid rebalancer");
        require(_admin != address(0), "Invalid admin");
        
        rebalancer = IBatchRebalancer(_rebalancer);
        gracePeriod = DEFAULT_GRACE_PERIOD;
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(GOVERNOR_ROLE, _admin);
        _grantRole(KEEPER_ROLE, _admin); // Admin can act as keeper initially
    }
    
    /**
     * @notice Opens a rebalancing window for a pie
     * @param pie The address of the PieVault to rebalance
     */
    function openWindow(address pie) external override whenNotPaused nonReentrant {
        require(pie != address(0), "Invalid pie address");
        
        // Calculate current window ID
        uint40 currentWindow = _calculateCurrentWindow(pie);
        
        // Check not already processed (idempotency)
        require(lastProcessedWindow[pie] < currentWindow, "Window already processed");
        
        // Validate timing and access
        bool withinTolerance = _isWithinWindowTolerance(pie, currentWindow);
        bool gracePeriodExpired = _isGracePeriodExpired(pie, currentWindow);
        
        // Check access: keeper within tolerance OR anyone after grace
        if (withinTolerance) {
            require(hasRole(KEEPER_ROLE, msg.sender), "Not authorized keeper");
        } else if (gracePeriodExpired) {
            // Anyone can execute after grace period
        } else {
            revert("Window not open");
        }
        
        // Update state before external call
        lastProcessedWindow[pie] = currentWindow;
        
        // Execute rebalancing
        rebalancer.processWindow(pie);
        
        // Emit event
        emit WindowOpened(pie, currentWindow, msg.sender);
    }
    
    /**
     * @notice Sets the grace period after which anyone can execute
     * @param gracePeriodSeconds The grace period in seconds
     */
    function setGracePeriod(uint32 gracePeriodSeconds) external override onlyRole(GOVERNOR_ROLE) {
        require(gracePeriodSeconds > 0, "Grace period must be positive");
        require(gracePeriodSeconds <= 86400, "Grace period too long"); // Max 1 day
        
        gracePeriod = gracePeriodSeconds;
        emit GracePeriodUpdated(gracePeriodSeconds);
    }
    
    /**
     * @notice Pauses window opening operations
     */
    function pause() external override onlyRole(GOVERNOR_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpauses window opening operations
     */
    function unpause() external override onlyRole(GOVERNOR_ROLE) {
        _unpause();
    }
    
    // ========== INTERNAL HELPERS ========== //
    
    /**
     * @dev Calculates the current window ID based on timestamp and schedule
     */
    function _calculateCurrentWindow(address pie) internal view returns (uint40) {
        // Get the window start time from the pie vault
        uint32 windowStartTimeUTC = IPieVault(pie).rebalanceWindowStartSecUTC();
        
        // Calculate days since epoch
        uint256 daysSinceEpoch = block.timestamp / 86400;
        
        // Ensure it fits in uint40 (over 3000 years from epoch)
        require(daysSinceEpoch <= type(uint40).max, "Window ID overflow");
        
        // Calculate the timestamp of today's window
        uint256 todayWindowTime = (daysSinceEpoch * 86400) + windowStartTimeUTC;
        
        // If we haven't reached today's window yet, use yesterday's window
        if (block.timestamp < todayWindowTime) {
            return uint40(daysSinceEpoch > 0 ? daysSinceEpoch - 1 : 0);
        }
        
        return uint40(daysSinceEpoch);
    }
    
    /**
     * @dev Validates that current time is within window opening tolerance
     */
    function _isWithinWindowTolerance(address pie, uint40 windowId) internal view returns (bool) {
        uint32 windowStartTimeUTC = IPieVault(pie).rebalanceWindowStartSecUTC();
        
        // Calculate the exact window time
        uint256 windowTime = (uint256(windowId) * 86400) + windowStartTimeUTC;
        
        // Check if we're within tolerance (±5 minutes)
        if (block.timestamp >= windowTime && block.timestamp <= windowTime + WINDOW_TOLERANCE) {
            return true;
        }
        
        // Also check if we're slightly before the window (for next day's window)
        if (windowTime > WINDOW_TOLERANCE && 
            block.timestamp >= windowTime - WINDOW_TOLERANCE && 
            block.timestamp < windowTime) {
            return true;
        }
        
        return false;
    }
    
    /**
     * @dev Checks if grace period has expired for anyone to execute
     */
    function _isGracePeriodExpired(address pie, uint40 windowId) internal view returns (bool) {
        uint32 windowStartTimeUTC = IPieVault(pie).rebalanceWindowStartSecUTC();
        
        // Calculate the exact window time
        uint256 windowTime = (uint256(windowId) * 86400) + windowStartTimeUTC;
        
        // Check if grace period has expired
        return block.timestamp > windowTime + gracePeriod;
    }
}