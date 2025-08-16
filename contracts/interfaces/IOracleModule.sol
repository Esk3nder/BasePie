// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IOracleModule {
    // Events
    event PriceUpdated(address indexed token, uint256 price, uint256 timestamp);
    event OracleHealthChanged(address indexed token, bool healthy);
    
    // Errors
    error StalePrice(address token, uint256 lastUpdate, uint256 maxStaleness);
    error UnhealthyOracle(address token);
    error UnsupportedToken(address token);
    
    // Get USD price for a token with health check
    function getUsdPrice(address token) 
        external 
        view 
        returns (
            uint256 priceE18,      // Price in USD with 18 decimals
            uint256 lastUpdateSec,  // Timestamp of last update
            bool healthy            // Whether price is reliable
        );
    
    // Batch price fetching for efficiency
    function getUsdPrices(address[] calldata tokens)
        external
        view
        returns (
            uint256[] memory pricesE18,
            uint256[] memory lastUpdatesSec,
            bool[] memory healthStatuses
        );
    
    // Configuration
    function setStalenessThreshold(uint256 seconds_) external;
    function setMaxDeviation(uint256 bps) external;
}