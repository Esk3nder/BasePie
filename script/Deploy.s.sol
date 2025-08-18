// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {PieFactory} from "../contracts/PieFactory.sol";
import {PieVault} from "../contracts/PieVault.sol";
import {BatchRebalancer} from "../contracts/BatchRebalancer.sol";
import {OracleModule} from "../contracts/core/OracleModule.sol";
import {TradeAdapter} from "../contracts/adapters/TradeAdapter.sol";
import {KeeperGate} from "../contracts/KeeperGate.sol";
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
    address public tradeAdapter;
    address public keeperGate;
    
    function run() external {
        // Deployment steps:
        // 1. Deploy OracleModule and configure feeds
        // 2. Deploy TradeAdapter
        // 3. Deploy BatchRebalancer
        // 4. Deploy PieVault implementation
        // 5. Deploy PieFactory with vault implementation
        // 6. Deploy KeeperGate
        // 7. Configure allowlist and roles
        // 8. Verify deployment
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Deploy OracleModule
        _deployOracleModule(deployer);
        
        // Step 2: Deploy TradeAdapter
        tradeAdapter = address(new TradeAdapter(deployer, address(0))); // Will set rebalancer after BatchRebalancer deployment
        console.log("TradeAdapter deployed at:", tradeAdapter);
        
        // Step 3: Deploy BatchRebalancer
        batchRebalancer = address(new BatchRebalancer(oracleModule, tradeAdapter));
        console.log("BatchRebalancer deployed at:", batchRebalancer);
        
        // Step 3.5: Grant REBALANCER_ROLE to BatchRebalancer
        TradeAdapter(tradeAdapter).grantRole(keccak256("REBALANCER"), batchRebalancer);
        console.log("Granted REBALANCER_ROLE to BatchRebalancer");
        
        // Step 4: Deploy PieVault implementation
        vaultImplementation = address(new PieVault());
        console.log("PieVault implementation deployed at:", vaultImplementation);
        
        // Step 5: Deploy PieFactory with vault implementation
        factory = address(new PieFactory(vaultImplementation, deployer));
        console.log("PieFactory deployed at:", factory);
        
        // Step 6: Deploy KeeperGate
        keeperGate = address(new KeeperGate(batchRebalancer, deployer));
        console.log("KeeperGate deployed at:", keeperGate);
        
        // Step 7: Configure initial allowlist
        _configureAllowlist();
        
        // Step 8: Verify deployment
        _verifyDeployment();
        
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
        // Set initial allowlist for common tokens
        PieFactory(factory).setGlobalAllowlist(USDC, true);
        PieFactory(factory).setGlobalAllowlist(WETH, true);
        console.log("Configured initial token allowlist");
        
        // TODO: Add more tokens based on requirements
        // Additional tokens can be added post-deployment via governance
    }
    
    /**
     * @dev Verify deployment configuration
     */
    function _verifyDeployment() internal view {
        // Verify PieFactory configuration
        require(PieFactory(factory).vaultImplementation() == vaultImplementation, "Invalid vault implementation");
        
        // Verify BatchRebalancer configuration
        require(address(BatchRebalancer(batchRebalancer).oracle()) == oracleModule, "Invalid oracle in rebalancer");
        require(address(BatchRebalancer(batchRebalancer).tradeAdapter()) == tradeAdapter, "Invalid trade adapter");
        
        // Verify role assignments
        bytes32 REBALANCER_ROLE = keccak256("REBALANCER");
        require(TradeAdapter(tradeAdapter).hasRole(REBALANCER_ROLE, batchRebalancer), "Rebalancer role not granted");
        
        // Verify KeeperGate configuration
        require(address(KeeperGate(keeperGate).rebalancer()) == batchRebalancer, "Invalid rebalancer in KeeperGate");
        
        console.log("Deployment verification successful!");
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
        console.log("KeeperGate:", keeperGate);
        console.log("==================================");
    }
}