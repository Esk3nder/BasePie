// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PieFactory} from "../contracts/PieFactory.sol";
import {IPieFactory} from "../contracts/interfaces/IPieFactory.sol";
import {PieVault} from "../contracts/PieVault.sol";

contract PieFactoryTest is Test {
    PieFactory public factory;
    PieVault public vaultImpl;
    
    // Test constants
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // Base USDC
    address public constant WETH = 0x4200000000000000000000000000000000000006; // Base WETH
    
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public governor = makeAddr("governor");
    
    event PieCreated(address indexed pie, address indexed creator, string name);
    event GlobalAllowlistUpdated(address indexed token, bool allowed);
    
    function setUp() public {
        // Deploy factory
        vm.prank(governor);
        factory = new PieFactory();
        
        // Deploy vault implementation
        vaultImpl = new PieVault();
        
        // Set up vault implementation
        vm.prank(governor);
        factory.setVaultImplementation(address(vaultImpl));
        
        // Set up allowlist
        vm.startPrank(governor);
        factory.setGlobalAllowlist(USDC, true);
        factory.setGlobalAllowlist(WETH, true);
        vm.stopPrank();
    }
    
    function test_createPie_success() public {
        // GIVEN: Valid parameters for pie creation
        string memory name = "Test Pie";
        string memory symbol = "TPIE";
        address[] memory assets = new address[](2);
        assets[0] = USDC;
        assets[1] = WETH;
        uint16[] memory weights = new uint16[](2);
        weights[0] = 6000; // 60%
        weights[1] = 4000; // 40%
        
        // WHEN: Creating a pie
        vm.expectEmit(true, true, false, true);
        emit PieCreated(address(0), alice, name); // Address will be determined
        
        vm.prank(alice);
        address pieAddress = factory.createPie(name, symbol, assets, weights, alice, 0, 0);
        
        // THEN: Should return valid pie address
        assertTrue(pieAddress != address(0));
        
        // Verify pie is in the list
        address[] memory pies = factory.getAllPies();
        assertEq(pies.length, 1);
        assertEq(pies[0], pieAddress);
    }
    
    function test_createPie_revertsInvalidWeights() public {
        // GIVEN: Invalid weights that don't sum to 10,000
        string memory name = "Invalid Pie";
        string memory symbol = "IPIE";
        address[] memory assets = new address[](2);
        assets[0] = USDC;
        assets[1] = WETH;
        uint16[] memory weights = new uint16[](2);
        weights[0] = 5000; // 50%
        weights[1] = 4000; // 40% - Total 90%, should fail
        
        // WHEN: Attempting to create pie
        // THEN: Should revert with invalid weights error
        
        vm.expectRevert("Weights must sum to 10000 bps");
        factory.createPie(name, symbol, assets, weights, alice, 0, 0);
    }
    
    function test_createPie_revertsNonAllowlistedToken() public {
        // GIVEN: Non-allowlisted token in assets
        string memory name = "Blocked Pie";
        string memory symbol = "BPIE";
        address[] memory assets = new address[](1);
        assets[0] = address(0xdead); // Non-allowlisted token
        uint16[] memory weights = new uint16[](1);
        weights[0] = 10000;
        
        // WHEN: Attempting to create pie
        // THEN: Should revert with non-allowlisted token error
        
        vm.expectRevert("Invalid or non-allowlisted asset");
        factory.createPie(name, symbol, assets, weights, alice, 0, 0);
    }
    
    function test_setGlobalAllowlist_onlyGovernor() public {
        // GIVEN: Non-governor trying to set allowlist
        address newToken = address(0x1234);
        
        // WHEN: Non-governor attempts to set allowlist
        // THEN: Should revert with access control error
        
        vm.prank(alice);
        vm.expectRevert(); // AccessControl revert
        factory.setGlobalAllowlist(newToken, true);
        
        // WHEN: Governor sets allowlist
        // THEN: Should succeed and emit event
        
        vm.expectEmit(true, false, false, true);
        emit GlobalAllowlistUpdated(newToken, true);
        
        vm.prank(governor);
        factory.setGlobalAllowlist(newToken, true);
        
        // Verify allowlist was updated
        assertTrue(factory.isTokenAllowed(newToken));
    }
    
    function test_createPie_emitsEvent() public {
        // Test event emission on successful pie creation
        string memory name = "Event Test Pie";
        string memory symbol = "EPIE";
        address[] memory assets = new address[](1);
        assets[0] = USDC;
        uint16[] memory weights = new uint16[](1);
        weights[0] = 10000;
        
        // Expect the event with correct parameters
        vm.expectEmit(true, true, false, true);
        emit PieCreated(address(0), alice, name); // Address will be determined by clone
        
        vm.prank(alice);
        address pieAddress = factory.createPie(name, symbol, assets, weights, alice, 0, 0);
        
        assertTrue(pieAddress != address(0));
    }
    
    function test_gasLimit_under500k() public {
        // GIVEN: Valid pie parameters
        string memory name = "Gas Test Pie";
        string memory symbol = "GPIE";
        address[] memory assets = new address[](5); // Test with 5 assets
        uint16[] memory weights = new uint16[](5);
        
        // Set up allowlist for test assets
        vm.startPrank(governor);
        for (uint i = 0; i < 5; i++) {
            assets[i] = address(uint160(0x1000 + i));
            weights[i] = 2000; // 20% each
            factory.setGlobalAllowlist(assets[i], true);
        }
        vm.stopPrank();
        
        // WHEN: Creating pie
        // THEN: Gas used should be under 500k
        
        uint256 gasBefore = gasleft();
        vm.prank(alice);
        factory.createPie(name, symbol, assets, weights, alice, 0, 0);
        uint256 gasUsed = gasBefore - gasleft();
        
        // Note: Gas measurement in tests is approximate
        assertLt(gasUsed, 500000, "Gas usage exceeds 500k");
    }
    
    function testFuzz_weightValidation(uint16[] memory weights) public {
        // GIVEN: Random weight arrays
        vm.assume(weights.length > 0 && weights.length <= 20);
        
        // Calculate sum
        uint256 sum = 0;
        for (uint i = 0; i < weights.length; i++) {
            sum += weights[i];
        }
        
        // Create matching assets array and set allowlist
        address[] memory assets = new address[](weights.length);
        vm.startPrank(governor);
        for (uint i = 0; i < weights.length; i++) {
            assets[i] = address(uint160(0x1000 + i));
            factory.setGlobalAllowlist(assets[i], true);
        }
        vm.stopPrank();
        
        // WHEN: Creating pie with these weights
        // THEN: Should only succeed if sum == 10,000
        
        if (sum == 10000) {
            // Should succeed
            vm.prank(alice);
            address pie = factory.createPie("Fuzz Pie", "FPIE", assets, weights, alice, 0, 0);
            assertTrue(pie != address(0));
        } else {
            // Should always revert with invalid weights
            vm.expectRevert("Weights must sum to 10000 bps");
            vm.prank(alice);
            factory.createPie("Fuzz Pie", "FPIE", assets, weights, alice, 0, 0);
        }
    }
}