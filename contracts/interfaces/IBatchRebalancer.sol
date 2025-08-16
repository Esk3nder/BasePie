// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IBatchRebalancer {
    // Events
    event WindowProcessed(
        uint40 indexed windowId,
        address indexed pie,
        uint256 navPre,
        uint256 navPost,
        uint256 gasUsed
    );
    
    event TradeExecuted(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    
    event DeltaComputed(
        address indexed token,
        int256 delta,
        uint256 currentValue,
        uint256 targetValue
    );
    
    // Main entry point for keeper
    function processWindow(address pie) external;
    
    // View functions for inspection
    function computePortfolioNav(address pie) external view returns (uint256 navUsdE18);
    
    function computeRebalanceDeltas(address pie) 
        external 
        returns (
            address[] memory tokens,
            int256[] memory deltas,
            uint256 navUsdE18
        );
}