// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {OracleModule} from "../contracts/core/OracleModule.sol";
import {IOracleModule} from "../contracts/interfaces/IOracleModule.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title OracleModule Test Suite
 * @notice Unit and integration tests for OracleModule price feed functionality
 */
contract OracleModuleTest is Test {
    // ============ Test Infrastructure ============
    
    OracleModule public oracle;
    address public admin = address(0x1);
    address public user = address(0x2);
    
    // Base mainnet addresses
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    
    // Mock feed for testing
    MockChainlinkFeed public mockEthFeed;
    MockChainlinkFeed public mockBtcFeed;
    
    // ============ Setup ============
    
    function setUp() public {
        // Deploy oracle with admin
        oracle = new OracleModule(admin);
        
        // Deploy mock feeds
        mockEthFeed = new MockChainlinkFeed(8, 200000000000); // $2000 with 8 decimals
        mockBtcFeed = new MockChainlinkFeed(8, 4000000000000); // $40000 with 8 decimals
    }
    
    // ============ Constructor Tests ============
    
    function test_Constructor_SetsAdmin() public {
        // Should set admin role correctly
        assertTrue(false, "Constructor should set admin role");
    }
    
    function test_Constructor_InitializesDefaults() public {
        // Should initialize staleness and deviation thresholds
        assertEq(oracle.stalenessThreshold(), 1800, "Should set 30 min staleness");
        assertEq(oracle.maxDeviationBps(), 200, "Should set 2% deviation");
    }
    
    // ============ USDC Special Case Tests ============
    
    function test_GetUsdPrice_USDC_ReturnsOneE18() public {
        // USDC should always return $1 (1e18)
        (uint256 price, uint256 updatedAt, bool healthy) = oracle.getUsdPrice(USDC);
        assertEq(price, 1e18, "USDC should return 1e18");
        assertEq(updatedAt, block.timestamp, "USDC should use current timestamp");
        assertTrue(healthy, "USDC should always be healthy");
    }
    
    // ============ Single Price Fetch Tests ============
    
    function test_GetUsdPrice_RegisteredToken_Success() public {
        // Register ETH feed
        vm.prank(admin);
        oracle.registerFeed(WETH, address(mockEthFeed));
        
        // Should fetch and normalize price
        (uint256 price, uint256 updatedAt, bool healthy) = oracle.getUsdPrice(WETH);
        assertEq(price, 2000e18, "Should normalize ETH price to 18 decimals");
        assertTrue(healthy, "Fresh price should be healthy");
    }
    
    function test_GetUsdPrice_UnregisteredToken_Reverts() public {
        // Should revert for unregistered token
        vm.expectRevert(IOracleModule.UnsupportedToken.selector);
        oracle.getUsdPrice(address(0x123));
    }
    
    function test_GetUsdPrice_StalePrice_Unhealthy() public {
        // Register feed and make it stale
        vm.prank(admin);
        oracle.registerFeed(WETH, address(mockEthFeed));
        
        // Fast forward past staleness threshold
        skip(1801); // 30 minutes + 1 second
        
        (uint256 price, , bool healthy) = oracle.getUsdPrice(WETH);
        assertFalse(healthy, "Stale price should be unhealthy");
    }
    
    // ============ Batch Price Fetch Tests ============
    
    function test_GetUsdPrices_MultipleTokens_Success() public {
        // Register multiple feeds
        vm.startPrank(admin);
        oracle.registerFeed(WETH, address(mockEthFeed));
        oracle.registerFeed(address(0x123), address(mockBtcFeed)); // Mock BTC
        vm.stopPrank();
        
        // Create token array
        address[] memory tokens = new address[](3);
        tokens[0] = USDC;
        tokens[1] = WETH;
        tokens[2] = address(0x123);
        
        // Fetch batch prices
        (uint256[] memory prices, uint256[] memory updates, bool[] memory healths) = 
            oracle.getUsdPrices(tokens);
        
        assertEq(prices.length, 3, "Should return 3 prices");
        assertEq(prices[0], 1e18, "USDC should be 1e18");
        assertEq(prices[1], 2000e18, "ETH should be 2000e18");
        assertEq(prices[2], 40000e18, "BTC should be 40000e18");
    }
    
    function test_GetUsdPrices_GasEfficiency() public {
        // Test gas usage for batch operations
        address[] memory tokens = new address[](10);
        for (uint i = 0; i < 10; i++) {
            tokens[i] = USDC; // Use USDC for simplicity
        }
        
        uint256 gasBefore = gasleft();
        oracle.getUsdPrices(tokens);
        uint256 gasUsed = gasBefore - gasleft();
        
        assertLt(gasUsed, 100000, "Batch operation should use < 100k gas for 10 tokens");
    }
    
    // ============ Decimal Normalization Tests ============
    
    function test_NormalizeDecimals_6Decimals() public {
        // Test with 6 decimal feed (like USDC feeds)
        MockChainlinkFeed feed6 = new MockChainlinkFeed(6, 1000000); // $1 with 6 decimals
        
        vm.prank(admin);
        oracle.registerFeed(address(0x456), address(feed6));
        
        (uint256 price, , ) = oracle.getUsdPrice(address(0x456));
        assertEq(price, 1e18, "Should normalize 6 decimals to 18");
    }
    
    function test_NormalizeDecimals_18Decimals() public {
        // Test with 18 decimal feed
        MockChainlinkFeed feed18 = new MockChainlinkFeed(18, 1500e18); // $1500 with 18 decimals
        
        vm.prank(admin);
        oracle.registerFeed(address(0x789), address(feed18));
        
        (uint256 price, , ) = oracle.getUsdPrice(address(0x789));
        assertEq(price, 1500e18, "Should handle 18 decimals correctly");
    }
    
    // ============ Admin Function Tests ============
    
    function test_RegisterFeed_OnlyAdmin() public {
        // Non-admin should not be able to register
        vm.prank(user);
        vm.expectRevert(); // AccessControl revert
        oracle.registerFeed(address(0x111), address(mockEthFeed));
    }
    
    function test_SetStalenessThreshold_UpdatesValue() public {
        vm.prank(admin);
        oracle.setStalenessThreshold(3600); // 1 hour
        
        assertEq(oracle.stalenessThreshold(), 3600, "Should update staleness threshold");
    }
    
    function test_SetMaxDeviation_UpdatesValue() public {
        vm.prank(admin);
        oracle.setMaxDeviation(500); // 5%
        
        assertEq(oracle.maxDeviationBps(), 500, "Should update max deviation");
    }
    
    // ============ Health Check Tests ============
    
    function test_PriceDeviation_MarksUnhealthy() public {
        // Register feed
        vm.prank(admin);
        oracle.registerFeed(WETH, address(mockEthFeed));
        
        // Get initial price (sets previous price)
        oracle.getUsdPrice(WETH);
        
        // Update mock feed with > 2% deviation
        mockEthFeed.updatePrice(204100000000); // $2041 (2.05% increase)
        
        (, , bool healthy) = oracle.getUsdPrice(WETH);
        assertFalse(healthy, "Large deviation should mark unhealthy");
    }
    
    // ============ Fork Tests (Base Mainnet) ============
    
    function testFork_RealChainlinkFeeds() public {
        // Skip if not forking
        if (block.chainid != 8453) return;
        
        // Test with real Chainlink feeds on Base
        // ETH/USD: 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70
        address ethUsdFeed = 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70;
        
        vm.prank(admin);
        oracle.registerFeed(WETH, ethUsdFeed);
        
        (uint256 price, , bool healthy) = oracle.getUsdPrice(WETH);
        assertGt(price, 1000e18, "ETH price should be > $1000");
        assertLt(price, 10000e18, "ETH price should be < $10000");
        assertTrue(healthy, "Live feed should be healthy");
    }
}

/**
 * @notice Mock Chainlink price feed for testing
 */
contract MockChainlinkFeed is AggregatorV3Interface {
    uint8 public decimals;
    int256 public price;
    uint256 public updatedAt;
    
    constructor(uint8 _decimals, int256 _price) {
        decimals = _decimals;
        price = _price;
        updatedAt = block.timestamp;
    }
    
    function updatePrice(int256 _price) external {
        price = _price;
        updatedAt = block.timestamp;
    }
    
    function makeStale() external {
        updatedAt = block.timestamp - 3601; // Make it > 1 hour old
    }
    
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 _updatedAt,
        uint80 answeredInRound
    ) {
        return (1, price, updatedAt, updatedAt, 1);
    }
    
    // Unused V3 interface methods
    function getRoundData(uint80) external pure returns (uint80, int256, uint256, uint256, uint80) {
        revert("Not implemented");
    }
    function version() external pure returns (uint256) {
        return 3;
    }
    function description() external pure returns (string memory) {
        return "Mock Feed";
    }
}