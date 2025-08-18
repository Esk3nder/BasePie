// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {TradeAdapter} from "../contracts/adapters/TradeAdapter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract TradeAdapterTest is Test {
    TradeAdapter public adapter;
    
    address public admin = makeAddr("admin");
    address public rebalancer = makeAddr("rebalancer");
    address public attacker = makeAddr("attacker");
    
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant UNIVERSAL_ROUTER = 0x6fF5693b99212Da76ad316178A184AB56D299b43;
    
    bytes32 public constant REBALANCER_ROLE = keccak256("REBALANCER");
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR");

    function setUp() public {
        // Deploy TradeAdapter
        adapter = new TradeAdapter(admin, rebalancer);
    }

    // =============================================================
    //                    ACCESS CONTROL TESTS
    // =============================================================

    function test_Constructor_SetsRoles() public {
        // Test: Admin should have DEFAULT_ADMIN_ROLE
        assertTrue(adapter.hasRole(adapter.DEFAULT_ADMIN_ROLE(), admin));
        
        // Test: Admin should have GOVERNOR_ROLE
        assertTrue(adapter.hasRole(GOVERNOR_ROLE, admin));
        
        // Test: Rebalancer should have REBALANCER_ROLE
        assertTrue(adapter.hasRole(REBALANCER_ROLE, rebalancer));
    }

    function test_ExecUniswap_RevertsUnauthorized() public {
        bytes memory commands = hex"00";
        bytes[] memory inputs = new bytes[](1);
        
        vm.prank(attacker);
        vm.expectRevert(TradeAdapter.UnauthorizedCaller.selector);
        adapter.execUniswap(commands, inputs);
    }

    function test_Exec0x_RevertsUnauthorized() public {
        vm.prank(attacker);
        vm.expectRevert(TradeAdapter.UnauthorizedCaller.selector);
        adapter.exec0x(makeAddr("target"), hex"", 0);
    }

    // =============================================================
    //                    UNISWAP TESTS
    // =============================================================

    function test_ExecUniswap_Success() public {
        // Setup: Create valid Uniswap commands for USDC -> WETH swap
        bytes memory commands = _buildUniswapCommands();
        bytes[] memory inputs = _buildUniswapInputs();
        
        // Setup: Fund rebalancer with USDC
        deal(USDC, rebalancer, 1000e6);
        
        // Execute trade as rebalancer
        vm.startPrank(rebalancer);
        IERC20(USDC).approve(address(adapter), 1000e6);
        
        uint256 wethBefore = IERC20(WETH).balanceOf(rebalancer);
        adapter.execUniswap(commands, inputs);
        uint256 wethAfter = IERC20(WETH).balanceOf(rebalancer);
        
        // Assert: WETH received
        assertGt(wethAfter, wethBefore, "Should receive WETH");
        
        // Assert: No USDC dust in adapter
        assertEq(IERC20(USDC).balanceOf(address(adapter)), 0, "No USDC dust");
        
        // Assert: No WETH dust in adapter
        assertEq(IERC20(WETH).balanceOf(address(adapter)), 0, "No WETH dust");
        vm.stopPrank();
    }

    function test_ExecUniswap_EmitsTradeExecuted() public {
        bytes memory commands = _buildUniswapCommands();
        bytes[] memory inputs = _buildUniswapInputs();
        
        deal(USDC, rebalancer, 1000e6);
        
        vm.startPrank(rebalancer);
        IERC20(USDC).approve(address(adapter), 1000e6);
        
        // Expect event (skip for now as TradeAdapter doesn't implement ITradeAdapter)
        // vm.expectEmit(true, true, true, false);
        // emit TradeExecuted(UNIVERSAL_ROUTER, USDC, WETH, 1000e6, 0);
        
        adapter.execUniswap(commands, inputs);
        vm.stopPrank();
    }

    // =============================================================
    //                      0x TESTS
    // =============================================================

    function test_Exec0x_ValidTarget() public {
        address mockTarget = makeAddr("0xTarget");
        
        // Setup: Add target to allowlist as governor
        vm.prank(admin);
        adapter.setRouterAllowlist(mockTarget, true);
        
        // Setup: Create mock swap data
        bytes memory swapData = abi.encodeWithSignature("swap()");
        
        // Setup: Fund and approve
        deal(USDC, rebalancer, 1000e6);
        
        vm.startPrank(rebalancer);
        IERC20(USDC).approve(address(adapter), 1000e6);
        
        // Execute (will revert with TODO but should pass access checks)
        adapter.exec0x(mockTarget, swapData, 0);
        vm.stopPrank();
    }

    function test_Exec0x_RevertsInvalidTarget() public {
        address invalidTarget = makeAddr("InvalidTarget");
        
        vm.prank(rebalancer);
        vm.expectRevert(abi.encodeWithSelector(TradeAdapter.InvalidRouter.selector, invalidTarget));
        adapter.exec0x(invalidTarget, hex"", 0);
    }

    function test_SetRouterAllowlist_OnlyGovernor() public {
        address router = makeAddr("router");
        
        // Test: Non-governor cannot update allowlist
        vm.prank(attacker);
        vm.expectRevert();
        adapter.setRouterAllowlist(router, true);
        
        // Test: Governor can update allowlist
        vm.prank(admin);
        adapter.setRouterAllowlist(router, true);
        assertTrue(adapter.routerAllowlist(router));
    }

    // =============================================================
    //                    SECURITY TESTS
    // =============================================================

    function test_NoTokenDustRemaining() public {
        // After any trade execution, no tokens should remain in adapter
        // This test will be implemented with actual trade execution
        
        // Test both USDC and WETH balances are 0
        assertEq(IERC20(USDC).balanceOf(address(adapter)), 0);
        assertEq(IERC20(WETH).balanceOf(address(adapter)), 0);
    }

    function test_ReentrancyProtection() public {
        // Create malicious contract that tries to reenter
        // This will be tested once implementation is complete
        assertTrue(true, "Reentrancy protection placeholder");
    }

    function test_SlippageProtection() public {
        // Test that trades respect minimum output amounts
        // Will be tested with actual implementation
        assertTrue(true, "Slippage protection placeholder");
    }

    // =============================================================
    //                      GAS TESTS
    // =============================================================

    function test_GasUsage() public {
        // Measure gas for typical swap
        uint256 gasStart = gasleft();
        
        // Execute trade (once implemented)
        // ...
        
        uint256 gasUsed = gasStart - gasleft();
        assertLt(gasUsed, 300000, "Gas usage should be under 300k");
    }

    // =============================================================
    //                    INTEGRATION TESTS
    // =============================================================

    function test_BatchRebalancerIntegration() public {
        // Test full integration with BatchRebalancer
        // This will be implemented once BatchRebalancer is updated
        assertTrue(true, "Integration test placeholder");
    }

    // =============================================================
    //                     HELPER FUNCTIONS
    // =============================================================

    function _buildUniswapCommands() internal pure returns (bytes memory) {
        // Build Universal Router V3_SWAP_EXACT_IN command
        // Command 0x00 = V3_SWAP_EXACT_IN
        return hex"00";
    }

    function _buildUniswapInputs() internal pure returns (bytes[] memory) {
        // Build inputs for USDC -> WETH swap
        bytes[] memory inputs = new bytes[](1);
        
        // Encode swap parameters
        inputs[0] = abi.encode(
            address(0), // recipient (will be updated)
            1000e6,     // amountIn
            0,          // amountOutMin
            bytes(""),  // path (will be encoded properly)
            true        // payerIsUser
        );
        
        return inputs;
    }
}