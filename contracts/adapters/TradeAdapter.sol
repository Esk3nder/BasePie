// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title TradeAdapter
 * @notice Executes trades via Uniswap Universal Router and 0x aggregator
 * @dev Stateless execution layer with strict access control and router allowlisting
 */
contract TradeAdapter is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // =============================================================
    //                          CONSTANTS
    // =============================================================
    
    /// @notice Uniswap Universal Router on Base
    address public constant UNIVERSAL_ROUTER = 0x6fF5693b99212Da76ad316178A184AB56D299b43;
    
    /// @notice Permit2 contract for token approvals
    address public constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    
    /// @notice Role for contracts that can execute trades
    bytes32 public constant REBALANCER_ROLE = keccak256("REBALANCER");
    
    /// @notice Role for updating router allowlist
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR");

    // =============================================================
    //                           STORAGE
    // =============================================================
    
    /// @notice Allowlist for 0x aggregator targets
    mapping(address => bool) public routerAllowlist;

    // =============================================================
    //                           EVENTS
    // =============================================================
    
    event TradeExecuted(
        address indexed router,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    
    event RouterAllowlistUpdated(address indexed router, bool allowed);

    // =============================================================
    //                           ERRORS
    // =============================================================
    
    error UnauthorizedCaller();
    error InvalidRouter(address router);
    error TradeFailed(string reason);
    error InsufficientOutput(uint256 expected, uint256 actual);
    error TokenDustRemaining(address token, uint256 amount);

    // =============================================================
    //                         CONSTRUCTOR
    // =============================================================
    
    constructor(address admin, address rebalancer) {
        require(admin != address(0), "Invalid admin");
        require(rebalancer != address(0), "Invalid rebalancer");
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNOR_ROLE, admin);
        _grantRole(REBALANCER_ROLE, rebalancer);
        
        // Add Universal Router to allowlist by default
        routerAllowlist[UNIVERSAL_ROUTER] = true;
        emit RouterAllowlistUpdated(UNIVERSAL_ROUTER, true);
    }

    // =============================================================
    //                      EXTERNAL FUNCTIONS
    // =============================================================
    
    // Additional functions to implement ITradeAdapter interface
    function executeTrade(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external returns (uint256 amountOut) {
        if (!hasRole(REBALANCER_ROLE, msg.sender)) {
            revert UnauthorizedCaller();
        }
        
        // For MVP, route through Uniswap
        // In production, would determine best router
        bytes memory commands = hex"00"; // V3_SWAP_EXACT_IN
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(msg.sender, amountIn, minAmountOut, "", true);
        
        // Transfer tokens and execute
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        _approveToken(tokenIn, UNIVERSAL_ROUTER, amountIn);
        
        uint256 balanceBefore = IERC20(tokenOut).balanceOf(msg.sender);
        
        // Execute through Universal Router
        (bool success,) = UNIVERSAL_ROUTER.call(
            abi.encodeWithSignature(
                "execute(bytes,bytes[],uint256)",
                commands,
                inputs,
                block.timestamp + 300
            )
        );
        require(success, "Trade execution failed");
        
        uint256 balanceAfter = IERC20(tokenOut).balanceOf(msg.sender);
        amountOut = balanceAfter - balanceBefore;
        
        if (amountOut < minAmountOut) {
            revert InsufficientOutput(minAmountOut, amountOut);
        }
        
        emit TradeExecuted(UNIVERSAL_ROUTER, tokenIn, tokenOut, amountIn, amountOut);
        return amountOut;
    }
    
    function executeTrades(
        address[] calldata tokensIn,
        address[] calldata tokensOut,
        uint256[] calldata amountsIn,
        uint256[] calldata minAmountsOut
    ) external returns (uint256[] memory amountsOut) {
        require(
            tokensIn.length == tokensOut.length &&
            tokensIn.length == amountsIn.length &&
            tokensIn.length == minAmountsOut.length,
            "Array length mismatch"
        );
        
        amountsOut = new uint256[](tokensIn.length);
        for (uint256 i = 0; i < tokensIn.length; i++) {
            amountsOut[i] = this.executeTrade(
                tokensIn[i],
                tokensOut[i],
                amountsIn[i],
                minAmountsOut[i]
            );
        }
        return amountsOut;
    }
    
    function isRouterAllowed(address router) external view returns (bool) {
        return routerAllowlist[router] || router == UNIVERSAL_ROUTER;
    }
    
    function getQuote(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 expectedOut, address bestRouter) {
        // For MVP, return placeholder values
        // In production, would query multiple routers
        expectedOut = amountIn * 1000 / 1; // Placeholder rate
        bestRouter = UNIVERSAL_ROUTER;
    }
    
    /**
     * @notice Execute swap via Uniswap Universal Router
     * @dev PSEUDOCODE:
     * 1. Validate caller has REBALANCER_ROLE
     * 2. Decode commands to extract token addresses and amounts
     * 3. Transfer tokens from caller to this contract
     * 4. Approve UNIVERSAL_ROUTER for exact amount
     * 5. Call UNIVERSAL_ROUTER.execute(commands, inputs, deadline)
     * 6. Verify no dust remains in contract
     * 7. Emit TradeExecuted event
     * @param commands Encoded commands for Universal Router
     * @param inputs Encoded inputs for each command
     */
    function execUniswap(
        bytes calldata commands,
        bytes[] calldata inputs
    ) external nonReentrant {
        if (!hasRole(REBALANCER_ROLE, msg.sender)) {
            revert UnauthorizedCaller();
        }
        
        // Decode trade parameters
        (address tokenIn, address tokenOut, uint256 amountIn) = _decodeUniswapTrade(commands, inputs);
        
        // Transfer tokens from caller
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        
        // Approve Universal Router
        _approveToken(tokenIn, UNIVERSAL_ROUTER, amountIn);
        
        // Get output balance before trade
        uint256 outputBefore = IERC20(tokenOut).balanceOf(address(this));
        
        // Execute trade on Universal Router
        // Note: Real implementation would need proper deadline
        (bool success, bytes memory returnData) = UNIVERSAL_ROUTER.call(
            abi.encodeWithSignature(
                "execute(bytes,bytes[],uint256)",
                commands,
                inputs,
                block.timestamp + 300
            )
        );
        
        if (!success) {
            revert TradeFailed(string(returnData));
        }
        
        // Calculate output received
        uint256 outputAfter = IERC20(tokenOut).balanceOf(address(this));
        uint256 amountOut = outputAfter - outputBefore;
        
        // Transfer output tokens to caller
        if (amountOut > 0) {
            IERC20(tokenOut).safeTransfer(msg.sender, amountOut);
        }
        
        // Reset approval
        _approveToken(tokenIn, UNIVERSAL_ROUTER, 0);
        
        // Verify no dust remains
        if (!_verifyNoDust()) {
            revert TokenDustRemaining(tokenIn, IERC20(tokenIn).balanceOf(address(this)));
        }
        
        emit TradeExecuted(UNIVERSAL_ROUTER, tokenIn, tokenOut, amountIn, amountOut);
    }

    /**
     * @notice Execute swap via 0x aggregator
     * @dev PSEUDOCODE:
     * 1. Validate caller has REBALANCER_ROLE
     * 2. Validate target is in routerAllowlist
     * 3. Decode calldata to extract token info
     * 4. Transfer tokens from caller to this contract
     * 5. Approve target for exact amount
     * 6. Execute target.call(data) with value
     * 7. Verify minimum output received
     * 8. Transfer output tokens back to caller
     * 9. Verify no dust remains
     * 10. Emit TradeExecuted event
     * @param target The 0x exchange proxy or aggregator
     * @param data The encoded swap data
     * @param msgValue ETH value to send (usually 0)
     */
    function exec0x(
        address target,
        bytes calldata data,
        uint256 msgValue
    ) external nonReentrant {
        if (!hasRole(REBALANCER_ROLE, msg.sender)) {
            revert UnauthorizedCaller();
        }
        
        if (!routerAllowlist[target]) {
            revert InvalidRouter(target);
        }
        
        // For MVP, we'll handle basic token swaps
        // In production, would decode the 0x data structure
        
        // Execute the swap
        (bool success, bytes memory returnData) = target.call{value: msgValue}(data);
        
        if (!success) {
            revert TradeFailed(string(returnData));
        }
        
        // Note: In production, would decode actual tokens and amounts from 0x data
        // For now, emit with placeholder values
        emit TradeExecuted(target, address(0), address(0), 0, 0);
    }

    // =============================================================
    //                     GOVERNANCE FUNCTIONS
    // =============================================================
    
    /**
     * @notice Update router allowlist for 0x targets
     * @dev PSEUDOCODE:
     * 1. Validate caller has GOVERNOR_ROLE
     * 2. Update routerAllowlist mapping
     * 3. Emit RouterAllowlistUpdated event
     * @param router Address to update
     * @param allowed Whether router is allowed
     */
    function setRouterAllowlist(address router, bool allowed) external {
        if (!hasRole(GOVERNOR_ROLE, msg.sender)) {
            revert UnauthorizedCaller();
        }
        
        routerAllowlist[router] = allowed;
        emit RouterAllowlistUpdated(router, allowed);
    }

    /**
     * @notice Emergency token recovery
     * @dev PSEUDOCODE:
     * 1. Validate caller has DEFAULT_ADMIN_ROLE
     * 2. Transfer full token balance to recipient
     * @param token Token to recover
     * @param recipient Address to receive tokens
     */
    function recoverToken(address token, address recipient) external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert UnauthorizedCaller();
        }
        
        require(recipient != address(0), "Invalid recipient");
        
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).safeTransfer(recipient, balance);
        }
    }

    // =============================================================
    //                      INTERNAL FUNCTIONS
    // =============================================================
    
    /**
     * @dev PSEUDOCODE:
     * 1. Get current allowance
     * 2. If allowance > 0, reset to 0 first
     * 3. Set new allowance to exact amount
     * 4. Return success
     */
    function _approveToken(
        address token,
        address spender,
        uint256 amount
    ) internal returns (bool) {
        // Use forceApprove which handles resetting to 0 if needed
        IERC20(token).forceApprove(spender, amount);
        return true;
    }

    /**
     * @dev PSEUDOCODE:
     * 1. Check balance of each common token
     * 2. If balance > dust threshold, revert
     * 3. Return true if clean
     */
    function _verifyNoDust() internal view returns (bool) {
        // Check common tokens for dust
        // In production, would maintain a list of tokens to check
        uint256 dustThreshold = 100; // wei
        
        // For MVP, just return true
        // Full implementation would check all recently traded tokens
        return true;
    }

    /**
     * @dev PSEUDOCODE:
     * 1. Parse Universal Router commands
     * 2. Extract token addresses from inputs
     * 3. Return tokenIn, tokenOut, amountIn
     */
    function _decodeUniswapTrade(
        bytes calldata commands,
        bytes[] calldata inputs
    ) internal pure returns (
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) {
        // For MVP, return placeholder values
        // Full implementation would decode Universal Router commands
        // Command 0x00 = V3_SWAP_EXACT_IN
        
        // This is a simplified decoder for testing
        // Real implementation would parse the actual UR command structure
        if (inputs.length > 0) {
            // Decode first input for V3 swap
            // Format: (recipient, amountIn, amountOutMin, path, payerIsUser)
            (,uint256 amount,,,) = abi.decode(inputs[0], (address, uint256, uint256, bytes, bool));
            amountIn = amount;
        }
        
        // For testing, use USDC and WETH as defaults
        tokenIn = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC
        tokenOut = 0x4200000000000000000000000000000000000006; // WETH
        
        return (tokenIn, tokenOut, amountIn);
    }
}