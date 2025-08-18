// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPieFactory} from "./interfaces/IPieFactory.sol";
import {IPieVault} from "./interfaces/IPieVault.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract PieFactory is IPieFactory, AccessControl, Pausable, ReentrancyGuard {
    using Clones for address;
    
    // Roles
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    
    // State
    mapping(address => bool) public tokenAllowlist;
    address[] public deployedPies;
    address public vaultImplementation;
    
    // Metrics for observability
    uint256 public totalPiesCreated;
    mapping(address => uint256) public userPieCount;
    
    // Constants
    uint16 public constant MAX_BPS = 10_000;
    uint256 public constant MAX_ASSETS = 20;
    
    constructor(address _vaultImplementation) {
        require(_vaultImplementation != address(0), "Invalid vault implementation");
        vaultImplementation = _vaultImplementation;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GOVERNOR_ROLE, msg.sender);
    }
    
    function createPie(
        string calldata name,
        string calldata symbol,
        address[] calldata assets,
        uint16[] calldata weightsBps,
        address feeReceiver,
        uint16 mgmtFeeBps,
        uint32 rebalanceWindowStartSecUTC
    ) external whenNotPaused nonReentrant returns (address pie) {
        // Validate vault implementation is set
        require(vaultImplementation != address(0), "Vault implementation not set");
        
        // Validate arrays
        require(assets.length > 0, "No assets provided");
        require(assets.length == weightsBps.length, "Assets and weights length mismatch");
        require(assets.length <= MAX_ASSETS, "Too many assets");
        
        // Validate all assets are allowlisted
        require(_validateAssets(assets), "Invalid or non-allowlisted asset");
        
        // Validate weights sum to exactly 10,000 bps
        require(_validateWeights(weightsBps), "Weights must sum to 10000 bps");
        
        // Clone vault implementation using EIP-1167
        pie = vaultImplementation.clone();
        
        // Initialize cloned vault with parameters
        IPieVault(pie).initialize(
            name,
            symbol,
            assets,
            weightsBps,
            msg.sender, // creator
            feeReceiver,
            mgmtFeeBps,
            rebalanceWindowStartSecUTC
        );
        
        // Store pie address in deployedPies array
        deployedPies.push(pie);
        
        // Update metrics
        totalPiesCreated++;
        userPieCount[msg.sender]++;
        
        // Emit PieCreated event
        emit PieCreated(pie, msg.sender, name);
    }
    
    function setGlobalAllowlist(address token, bool allowed) external onlyRole(GOVERNOR_ROLE) {
        require(token != address(0), "Invalid token address");
        tokenAllowlist[token] = allowed;
        emit GlobalAllowlistUpdated(token, allowed);
    }
    
    function setVaultImplementation(address newImplementation) external onlyRole(GOVERNOR_ROLE) {
        require(newImplementation != address(0), "Invalid implementation address");
        require(newImplementation.code.length > 0, "Implementation must be a contract");
        vaultImplementation = newImplementation;
        emit VaultImplementationUpdated(newImplementation);
    }
    
    function isTokenAllowed(address token) external view returns (bool) {
        return tokenAllowlist[token];
    }
    
    function getAllPies() external view returns (address[] memory) {
        return deployedPies;
    }
    
    // Admin functions for emergency control
    function pause() external onlyRole(GOVERNOR_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(GOVERNOR_ROLE) {
        _unpause();
    }
    
    // Internal helper functions
    function _validateWeights(uint16[] calldata weightsBps) internal pure returns (bool) {
        uint256 sum = 0;
        for (uint256 i = 0; i < weightsBps.length; i++) {
            sum += weightsBps[i];
        }
        return sum == MAX_BPS;
    }
    
    function _validateAssets(address[] calldata assets) internal view returns (bool) {
        for (uint256 i = 0; i < assets.length; i++) {
            // Check if asset is allowlisted
            if (!tokenAllowlist[assets[i]]) {
                return false;
            }
            
            // Check for duplicates
            for (uint256 j = i + 1; j < assets.length; j++) {
                if (assets[i] == assets[j]) {
                    return false;
                }
            }
        }
        return true;
    }
}