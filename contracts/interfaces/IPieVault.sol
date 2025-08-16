// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPieVault {
    // Minimal interface for factory to interact with vault
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
    
    function asset() external view returns (address);
    function totalAssets() external view returns (uint256);
}