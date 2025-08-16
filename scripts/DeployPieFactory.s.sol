// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {PieFactory} from "../contracts/PieFactory.sol";

contract DeployPieFactory is Script {
    // Base mainnet addresses
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    
    function run() external returns (address factory) {
        // PSEUDOCODE:
        // 1. Load deployer private key from env
        // 2. Start broadcast
        // 3. Deploy PieFactory
        // 4. Set initial vault implementation (once PieVault exists)
        // 5. Set initial allowlist for common tokens (USDC, WETH, etc)
        // 6. Transfer admin roles if needed
        // 7. Stop broadcast
        // 8. Log deployed addresses
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy factory
        factory = address(new PieFactory());
        
        // TODO: Set vault implementation once PieVault is created
        // PieFactory(factory).setVaultImplementation(vaultImpl);
        
        // TODO: Set initial allowlist
        // PieFactory(factory).setGlobalAllowlist(USDC, true);
        // PieFactory(factory).setGlobalAllowlist(WETH, true);
        
        vm.stopBroadcast();
        
        // Log deployment
        _logDeployment(factory);
        
        return factory;
    }
    
    function _logDeployment(address factory) internal view {
        console.log("===== PieFactory Deployment =====");
        console.log("PieFactory deployed at:", factory);
        console.log("Network: Base");
        console.log("=================================");
    }
}