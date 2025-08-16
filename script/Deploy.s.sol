// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {PieFactory} from "../contracts/PieFactory.sol";
import {PieVault} from "../contracts/core/PieVault.sol";
import {BatchRebalancer} from "../contracts/core/BatchRebalancer.sol";
import {OracleModule} from "../contracts/core/OracleModule.sol";
import {BaseFeedRegistry} from "./config/BaseFeedRegistry.sol";

/**
 * @title Deploy Script
 * @notice Main deployment script for BasePie MVP contracts
 * @dev Deploys all core contracts and configures initial state
 */
contract Deploy is Script {
    // Base mainnet addresses
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    
    // Deployed contracts
    address public factory;
    address public vaultImplementation;
    address public oracleModule;
    address public batchRebalancer;
    address public tradeAdapter; // TODO: Implement TradeAdapter
    
    function run() external {
        // PSEUDOCODE:
        // 1. Load deployer key and start broadcast
        // 2. Deploy OracleModule
        // 3. Configure Oracle with Chainlink feeds
        // 4. Deploy TradeAdapter (when implemented)
        // 5. Deploy BatchRebalancer with Oracle and TradeAdapter
        // 6. Deploy PieVault implementation
        // 7. Deploy PieFactory with vault implementation
        // 8. Set initial token allowlist
        // 9. Configure roles and permissions
        // 10. Stop broadcast and log addresses
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Deploy OracleModule
        _deployOracleModule(deployer);
        
        // Step 2: Deploy TradeAdapter (TODO)
        // tradeAdapter = address(new TradeAdapter());
        
        // Step 3: Deploy BatchRebalancer (TODO - needs TradeAdapter)
        // batchRebalancer = address(new BatchRebalancer(oracleModule, tradeAdapter));
        
        // Step 4: Deploy PieVault implementation (TODO)
        // vaultImplementation = address(new PieVault());
        
        // Step 5: Deploy PieFactory (TODO - needs vault implementation)
        // factory = address(new PieFactory());
        // PieFactory(factory).setVaultImplementation(vaultImplementation);
        
        // Step 6: Configure initial allowlist (TODO)
        // _configureAllowlist();
        
        vm.stopBroadcast();
        
        // Log all deployed addresses
        _logDeployment();
    }
    
    /**
     * @dev Deploy and configure OracleModule
     */
    function _deployOracleModule(address admin) internal {
        // Deploy OracleModule
        oracleModule = address(new OracleModule(admin));
        console.log("OracleModule deployed at:", oracleModule);
        
        // Register Chainlink feeds based on network
        if (block.chainid == 8453) { // Base mainnet
            console.log("Configuring for Base mainnet...");
            BaseFeedRegistry.FeedConfig[] memory feeds = BaseFeedRegistry.getMainnetFeeds();
            for (uint i = 0; i < feeds.length; i++) {
                // Skip USDC since it's handled specially in the Oracle
                if (feeds[i].token == USDC) continue;
                
                OracleModule(oracleModule).registerFeed(feeds[i].token, feeds[i].feed);
                console.log("Registered feed:", feeds[i].description);
            }
        } else if (block.chainid == 84532) { // Base Sepolia
            console.log("Configuring for Base Sepolia testnet...");
            BaseFeedRegistry.FeedConfig[] memory feeds = BaseFeedRegistry.getSepoliaFeeds();
            for (uint i = 0; i < feeds.length; i++) {
                // Skip if token address is zero
                if (feeds[i].token == address(0)) continue;
                
                OracleModule(oracleModule).registerFeed(feeds[i].token, feeds[i].feed);
                console.log("Registered feed:", feeds[i].description);
            }
        } else {
            console.log("Warning: Unknown network, skipping feed registration");
        }
    }
    
    /**
     * @dev Configure initial token allowlist
     */
    function _configureAllowlist() internal {
        // TODO: Implement when PieFactory is deployed
        // PSEUDOCODE:
        // PieFactory(factory).setGlobalAllowlist(USDC, true);
        // PieFactory(factory).setGlobalAllowlist(WETH, true);
        // Add more tokens as needed
    }
    
    /**
     * @dev Log all deployed contract addresses
     */
    function _logDeployment() internal view {
        console.log("===== BasePie MVP Deployment =====");
        console.log("Network Chain ID:", block.chainid);
        console.log("OracleModule:", oracleModule);
        console.log("TradeAdapter:", tradeAdapter);
        console.log("BatchRebalancer:", batchRebalancer);
        console.log("Vault Implementation:", vaultImplementation);
        console.log("PieFactory:", factory);
        console.log("==================================");
    }
}