// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {KeeperGate} from "../contracts/KeeperGate.sol";
import {IKeeperGate} from "../contracts/interfaces/IKeeperGate.sol";
import {PieVault} from "../contracts/PieVault.sol";
import {BatchRebalancer} from "../contracts/BatchRebalancer.sol";
import {OracleModule} from "../contracts/core/OracleModule.sol";
import {TradeAdapter} from "../contracts/adapters/TradeAdapter.sol";
import {PieFactory} from "../contracts/PieFactory.sol";

contract KeeperGateTest is Test {
    KeeperGate public keeperGate;
    PieFactory public factory;
    PieVault public pieVault;
    BatchRebalancer public rebalancer;
    OracleModule public oracle;
    TradeAdapter public tradeAdapter;
    
    address public admin = makeAddr("admin");
    address public keeper = makeAddr("keeper");
    address public user = makeAddr("user");
    address public pieCreator = makeAddr("creator");
    
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    
    uint32 public constant WINDOW_START_TIME = 54000; // 15:00:00 UTC in seconds from midnight
    
    function setUp() public {
        // Deploy infrastructure
        oracle = new OracleModule(admin);
        tradeAdapter = new TradeAdapter(admin, address(0));
        rebalancer = new BatchRebalancer(address(oracle), address(tradeAdapter));
        
        // Deploy PieVault implementation
        PieVault vaultImpl = new PieVault();
        
        // Deploy factory
        factory = new PieFactory(address(vaultImpl));
        
        // Deploy KeeperGate
        keeperGate = new KeeperGate(address(rebalancer), admin);
        
        // Setup roles
        vm.startPrank(admin);
        keeperGate.grantRole(keeperGate.KEEPER_ROLE(), keeper);
        tradeAdapter.grantRole(keccak256("REBALANCER"), address(rebalancer));
        vm.stopPrank();
        
        // Create a test pie
        _createTestPie();
    }
    
    function _createTestPie() internal {
        vm.startPrank(admin);
        factory.setGlobalAllowlist(USDC, true);
        factory.setGlobalAllowlist(WETH, true);
        vm.stopPrank();
        
        address[] memory assets = new address[](2);
        assets[0] = WETH;
        assets[1] = USDC;
        
        uint16[] memory weights = new uint16[](2);
        weights[0] = 6000; // 60%
        weights[1] = 4000; // 40%
        
        vm.prank(pieCreator);
        address pie = factory.createPie(
            "Test Pie",
            "TPIE",
            assets,
            weights,
            pieCreator,
            0,
            WINDOW_START_TIME
        );
        
        pieVault = PieVault(pie);
    }
    
    /**
     * @notice Test successful window opening by keeper
     * Expected: Window opens when called at correct time by keeper
     */
    function testOpenWindow_Success() public {
        // Set time to exactly window start time
        uint256 windowTime = _getNextWindowTime();
        vm.warp(windowTime);
        
        // Calculate expected window ID
        uint40 expectedWindowId = uint40(windowTime / 86400);
        
        vm.prank(keeper);
        keeperGate.openWindow(address(pieVault));
        
        // Should have processed the expected window
        assertEq(keeperGate.lastProcessedWindow(address(pieVault)), expectedWindowId, "Window not processed");
    }
    
    /**
     * @notice Test window opening reverts when too early
     * Expected: Reverts if called before tolerance window
     */
    function testOpenWindow_RevertsTooEarly() public {
        uint256 windowTime = _getNextWindowTime();
        // Set time to 6 minutes before window (outside 5 min tolerance)
        vm.warp(windowTime - 360);
        
        vm.prank(keeper);
        vm.expectRevert();
        keeperGate.openWindow(address(pieVault));
    }
    
    /**
     * @notice Test window opening reverts when too late
     * Expected: Reverts if called after tolerance window (but before grace)
     */
    function testOpenWindow_RevertsTooLate() public {
        uint256 windowTime = _getNextWindowTime();
        // Set time to 6 minutes after window (outside 5 min tolerance)
        vm.warp(windowTime + 360);
        
        vm.prank(keeper);
        vm.expectRevert();
        keeperGate.openWindow(address(pieVault));
    }
    
    /**
     * @notice Test prevention of double execution
     * Expected: Cannot process same window twice
     */
    function testOpenWindow_RevertsDoubleExecution() public {
        uint256 windowTime = _getNextWindowTime();
        vm.warp(windowTime);
        
        // First execution succeeds
        vm.prank(keeper);
        keeperGate.openWindow(address(pieVault));
        
        // Second execution should revert
        vm.prank(keeper);
        vm.expectRevert();
        keeperGate.openWindow(address(pieVault));
    }
    
    /**
     * @notice Test anyone can execute after grace period
     * Expected: Non-keeper can execute after grace period expires
     */
    function testOpenWindow_AnyoneCanExecuteAfterGrace() public {
        uint256 windowTime = _getNextWindowTime();
        // Set time to after grace period (30 min default)
        vm.warp(windowTime + keeperGate.gracePeriod() + 1);
        
        // Calculate expected window ID
        uint40 expectedWindowId = uint40(windowTime / 86400);
        
        // Random user should be able to execute
        vm.prank(user);
        keeperGate.openWindow(address(pieVault));
        
        assertEq(keeperGate.lastProcessedWindow(address(pieVault)), expectedWindowId, "Window not processed by user");
    }
    
    /**
     * @notice Test window opening reverts when paused
     * Expected: All window operations blocked when paused
     */
    function testOpenWindow_RevertsWhenPaused() public {
        vm.prank(admin);
        keeperGate.pause();
        
        uint256 windowTime = _getNextWindowTime();
        vm.warp(windowTime);
        
        vm.prank(keeper);
        vm.expectRevert("Pausable: paused");
        keeperGate.openWindow(address(pieVault));
    }
    
    /**
     * @notice Test setting grace period (only governor)
     * Expected: Only governor can update grace period
     */
    function testSetGracePeriod_OnlyGovernor() public {
        // Admin (governor) can set
        vm.prank(admin);
        keeperGate.setGracePeriod(3600); // 1 hour
        assertEq(keeperGate.gracePeriod(), 3600, "Grace period not updated");
        
        // Non-governor cannot set
        vm.prank(user);
        vm.expectRevert();
        keeperGate.setGracePeriod(7200);
    }
    
    /**
     * @notice Fuzz test window timing boundaries
     * Expected: Window opens only within valid timing bounds
     */
    function testFuzz_WindowTimingBoundaries(uint256 timeOffset) public {
        timeOffset = bound(timeOffset, 0, 86400); // Bound to 1 day
        uint256 windowTime = _getNextWindowTime();
        
        vm.warp(windowTime + timeOffset);
        
        bool shouldSucceed = timeOffset <= 300 || // Within 5 min after
                            (timeOffset >= (86400 - 300)); // Within 5 min before (next day)
        
        if (shouldSucceed || timeOffset > keeperGate.gracePeriod()) {
            // Should either be in tolerance or after grace
            vm.prank(timeOffset > keeperGate.gracePeriod() ? user : keeper);
            keeperGate.openWindow(address(pieVault));
        } else {
            // Should revert
            vm.prank(keeper);
            vm.expectRevert();
            keeperGate.openWindow(address(pieVault));
        }
    }
    
    // ========== HELPERS ========== //
    
    function _getNextWindowTime() internal view returns (uint256) {
        uint256 daysSinceEpoch = block.timestamp / 86400;
        return (daysSinceEpoch * 86400) + WINDOW_START_TIME;
    }
}