// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ITradeAdapter {
    // Events
    event TradeExecuted(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address indexed router
    );
    
    event RouterAllowlistUpdated(address indexed router, bool allowed);
    
    // Errors
    error InsufficientOutput(uint256 amountOut, uint256 minAmountOut);
    error RouterNotAllowed(address router);
    error TradeFailed(string reason);
    
    // Trade execution
    function executeTrade(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external returns (uint256 amountOut);
    
    // Batch trading for gas efficiency
    function executeTrades(
        address[] calldata tokensIn,
        address[] calldata tokensOut,
        uint256[] calldata amountsIn,
        uint256[] calldata minAmountsOut
    ) external returns (uint256[] memory amountsOut);
    
    // Router management
    function setRouterAllowlist(address router, bool allowed) external;
    function isRouterAllowed(address router) external view returns (bool);
    
    // Quote functions (view only)
    function getQuote(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 expectedOut, address bestRouter);
}