// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IKeeperGate
 * @notice Interface for the KeeperGate contract that manages rebalancing windows
 * @dev Controls when and who can trigger pie rebalancing operations
 */
interface IKeeperGate {
    /**
     * @notice Emitted when a rebalancing window is successfully opened
     * @param pie The address of the PieVault
     * @param windowId The ID of the window that was opened
     * @param opener The address that opened the window
     */
    event WindowOpened(address indexed pie, uint40 windowId, address opener);
    
    /**
     * @notice Emitted when the grace period is updated
     * @param newPeriod The new grace period in seconds
     */
    event GracePeriodUpdated(uint32 newPeriod);
    
    /**
     * @notice Opens a rebalancing window for a pie
     * @dev Validates timing, prevents double execution, triggers rebalancing
     * @param pie The address of the PieVault to rebalance
     */
    function openWindow(address pie) external;
    
    /**
     * @notice Sets the grace period after which anyone can execute
     * @param gracePeriodSeconds The grace period in seconds
     */
    function setGracePeriod(uint32 gracePeriodSeconds) external;
    
    /**
     * @notice Pauses window opening operations
     */
    function pause() external;
    
    /**
     * @notice Unpauses window opening operations
     */
    function unpause() external;
    
    /**
     * @notice Gets the last processed window for a pie
     * @param pie The address of the PieVault
     * @return The last processed window ID
     */
    function lastProcessedWindow(address pie) external view returns (uint40);
    
    /**
     * @notice Gets the current grace period
     * @return The grace period in seconds
     */
    function gracePeriod() external view returns (uint32);
}