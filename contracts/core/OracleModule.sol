// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IOracleModule} from "../interfaces/IOracleModule.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title OracleModule
 * @notice Provides USD price discovery using Chainlink price feeds on Base network
 * @dev Implements IOracleModule with health monitoring and decimal normalization
 */
contract OracleModule is IOracleModule, AccessControl {
    // ============ Constants ============
    
    bytes32 public constant ORACLE_ADMIN_ROLE = keccak256("ORACLE_ADMIN_ROLE");
    uint256 public constant PRECISION = 1e18;
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // Base USDC
    
    // ============ State Variables ============
    
    /// @notice Mapping from token address to Chainlink price feed address
    mapping(address => address) public tokenToFeed;
    
    /// @notice Cached decimals for each price feed to save gas
    mapping(address => uint8) public feedDecimals;
    
    /// @notice Maximum age for price data in seconds (default: 30 minutes)
    uint256 public stalenessThreshold;
    
    /// @notice Maximum price deviation in basis points (default: 200 = 2%)
    uint256 public maxDeviationBps;
    
    /// @notice Previous prices for deviation checks
    mapping(address => uint256) public previousPrices;
    
    // ============ Events ============
    
    event FeedRegistered(address indexed token, address indexed feed);
    event StalenessThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event MaxDeviationUpdated(uint256 oldDeviation, uint256 newDeviation);
    
    // ============ Constructor ============
    
    constructor(address admin) {
        require(admin != address(0), "Invalid admin");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ORACLE_ADMIN_ROLE, admin);
        
        stalenessThreshold = 1800; // 30 minutes
        maxDeviationBps = 200; // 2%
    }
    
    // ============ External Functions ============
    
    /**
     * @notice Get USD price for a single token
     * @param token The token address to get price for
     * @return priceE18 The price in USD with 18 decimals
     * @return lastUpdateSec Timestamp of last price update
     * @return healthy Whether the price feed is healthy
     */
    function getUsdPrice(address token) 
        external 
        view 
        returns (
            uint256 priceE18,
            uint256 lastUpdateSec,
            bool healthy
        ) 
    {
        // Check for special tokens
        (bool isSpecial, uint256 specialPrice) = _handleSpecialToken(token);
        if (isSpecial) {
            return (specialPrice, block.timestamp, true);
        }
        
        // Get feed address
        address feed = tokenToFeed[token];
        if (feed == address(0)) {
            revert UnsupportedToken(token);
        }
        
        // Fetch price from Chainlink
        (priceE18, lastUpdateSec) = _fetchChainlinkPrice(feed);
        
        // Check health
        healthy = _checkHealth(token, priceE18, lastUpdateSec);
        
        return (priceE18, lastUpdateSec, healthy);
    }
    
    /**
     * @notice Get USD prices for multiple tokens in a single call
     * @param tokens Array of token addresses
     * @return pricesE18 Array of prices in USD with 18 decimals
     * @return lastUpdatesSec Array of last update timestamps
     * @return healthStatuses Array of health status flags
     */
    function getUsdPrices(address[] calldata tokens)
        external
        view
        returns (
            uint256[] memory pricesE18,
            uint256[] memory lastUpdatesSec,
            bool[] memory healthStatuses
        )
    {
        uint256 length = tokens.length;
        pricesE18 = new uint256[](length);
        lastUpdatesSec = new uint256[](length);
        healthStatuses = new bool[](length);
        
        for (uint256 i = 0; i < length; i++) {
            address token = tokens[i];
            
            // Check for special tokens
            (bool isSpecial, uint256 specialPrice) = _handleSpecialToken(token);
            if (isSpecial) {
                pricesE18[i] = specialPrice;
                lastUpdatesSec[i] = block.timestamp;
                healthStatuses[i] = true;
                continue;
            }
            
            // Get feed address
            address feed = tokenToFeed[token];
            if (feed == address(0)) {
                revert UnsupportedToken(token);
            }
            
            // Fetch price from Chainlink
            (pricesE18[i], lastUpdatesSec[i]) = _fetchChainlinkPrice(feed);
            
            // Check health
            healthStatuses[i] = _checkHealth(token, pricesE18[i], lastUpdatesSec[i]);
        }
        
        return (pricesE18, lastUpdatesSec, healthStatuses);
    }
    
    /**
     * @notice Set the staleness threshold for price feeds
     * @param seconds_ Maximum age for price data in seconds
     */
    function setStalenessThreshold(uint256 seconds_) external onlyRole(ORACLE_ADMIN_ROLE) {
        require(seconds_ >= 60 && seconds_ <= 3600, "Invalid threshold");
        uint256 oldThreshold = stalenessThreshold;
        stalenessThreshold = seconds_;
        emit StalenessThresholdUpdated(oldThreshold, seconds_);
    }
    
    /**
     * @notice Set the maximum allowed price deviation
     * @param bps Maximum deviation in basis points
     */
    function setMaxDeviation(uint256 bps) external onlyRole(ORACLE_ADMIN_ROLE) {
        require(bps > 0 && bps <= 1000, "Invalid deviation");
        uint256 oldDeviation = maxDeviationBps;
        maxDeviationBps = bps;
        emit MaxDeviationUpdated(oldDeviation, bps);
    }
    
    /**
     * @notice Register a Chainlink price feed for a token
     * @param token The token address
     * @param feed The Chainlink aggregator address
     */
    function registerFeed(address token, address feed) external onlyRole(ORACLE_ADMIN_ROLE) {
        require(token != address(0), "Invalid token");
        require(feed != address(0), "Invalid feed");
        
        // Store feed address
        tokenToFeed[token] = feed;
        
        // Cache feed decimals
        uint8 decimals = AggregatorV3Interface(feed).decimals();
        feedDecimals[feed] = decimals;
        
        // Test price fetch to ensure feed works
        (
            ,
            int256 answer,
            ,
            uint256 updatedAt,
            
        ) = AggregatorV3Interface(feed).latestRoundData();
        require(answer > 0, "Invalid price");
        require(updatedAt > 0, "Invalid timestamp");
        
        emit FeedRegistered(token, feed);
    }
    
    // ============ Internal Functions ============
    
    /**
     * @dev Fetch price from Chainlink and normalize to 18 decimals
     */
    function _fetchChainlinkPrice(address feed) 
        internal 
        view 
        returns (uint256 priceE18, uint256 updatedAt) 
    {
        (
            ,
            int256 answer,
            ,
            uint256 _updatedAt,
            
        ) = AggregatorV3Interface(feed).latestRoundData();
        
        require(answer > 0, "Invalid price");
        require(_updatedAt > 0, "Invalid timestamp");
        
        // Get cached decimals
        uint8 decimals = feedDecimals[feed];
        if (decimals == 0) {
            decimals = AggregatorV3Interface(feed).decimals();
        }
        
        // Normalize to 18 decimals
        uint256 price = uint256(answer);
        if (decimals < 18) {
            priceE18 = price * 10**(18 - decimals);
        } else if (decimals > 18) {
            priceE18 = price / 10**(decimals - 18);
        } else {
            priceE18 = price;
        }
        
        return (priceE18, _updatedAt);
    }
    
    /**
     * @dev Check if price feed is healthy based on staleness and deviation
     */
    function _checkHealth(address token, uint256 price, uint256 updatedAt) 
        internal 
        view 
        returns (bool healthy) 
    {
        // Check staleness
        if (block.timestamp - updatedAt > stalenessThreshold) {
            return false;
        }
        
        // Check deviation if previous price exists
        uint256 prevPrice = previousPrices[token];
        if (prevPrice > 0) {
            uint256 deviation;
            if (price > prevPrice) {
                deviation = ((price - prevPrice) * 10000) / prevPrice;
            } else {
                deviation = ((prevPrice - price) * 10000) / prevPrice;
            }
            
            if (deviation > maxDeviationBps) {
                return false;
            }
        }
        
        return true;
    }
    
    /**
     * @dev Handle special tokens like USDC that don't need oracle
     */
    function _handleSpecialToken(address token) 
        internal 
        pure 
        returns (bool handled, uint256 price) 
    {
        if (token == USDC) {
            return (true, PRECISION); // USDC is always $1
        }
        return (false, 0);
    }
}