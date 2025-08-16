// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPieFactory {
    // Events
    event PieCreated(address indexed pie, address indexed creator, string name);
    event GlobalAllowlistUpdated(address indexed token, bool allowed);
    event VaultImplementationUpdated(address indexed newImplementation);
    
    // Core Functions
    function createPie(
        string calldata name,
        string calldata symbol,
        address[] calldata assets,
        uint16[] calldata weightsBps,
        address feeReceiver,
        uint16 mgmtFeeBps,
        uint32 rebalanceWindowStartSecUTC
    ) external returns (address pie);
    
    // Admin Functions
    function setGlobalAllowlist(address token, bool allowed) external;
    function setVaultImplementation(address newImplementation) external;
    
    // View Functions
    function isTokenAllowed(address token) external view returns (bool);
    function getAllPies() external view returns (address[] memory);
    function vaultImplementation() external view returns (address);
}