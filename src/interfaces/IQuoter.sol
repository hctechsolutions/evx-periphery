// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IQuoter
 * @notice Interface for computing expected swap outcomes without executing them.
 * @dev Quotes use reverts and simulated swaps, and are not gas-efficient. Not intended for on-chain usage.
 */
interface IQuoter {
    /**
     * @notice Returns the expected output amount for a given exact input swap.
     * @dev Simulates the swap across multiple pools encoded in the path. Not marked as `view` due to internal reverts.
     * @param path The encoded path of token pairs and pool fees.
     * @param amountIn The amount of input token to swap.
     * @return amountOut The estimated amount of output token received.
     * @return sqrtPriceX96AfterList The sqrt price after each pool swap along the path.
     * @return initializedTicksCrossedList Number of initialized ticks crossed in each pool.
     * @return gasEstimate Estimated gas consumed by the full swap.
     */
    function quoteExactInput(bytes memory path, uint256 amountIn)
        external
        returns (
            uint256 amountOut,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksCrossedList,
            uint256 gasEstimate
        );

    /// @notice Parameters for quoting an exact input on a single pool.
    struct QuoteExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint24 fee;
        uint160 sqrtPriceLimitX96;
    }

    /**
     * @notice Returns the expected output for a given exact input swap on a single pool.
     * @param params Struct with swap configuration: tokenIn, tokenOut, fee, amountIn, and optional sqrt price limit.
     * @return amountOut Estimated amount of output token received.
     * @return sqrtPriceX96After Sqrt price after the swap.
     * @return initializedTicksCrossed Number of initialized ticks crossed.
     * @return gasEstimate Estimated gas used during the simulation.
     */
    function quoteExactInputSingle(QuoteExactInputSingleParams memory params)
        external
        returns (
            uint256 amountOut,
            uint160 sqrtPriceX96After,
            uint32 initializedTicksCrossed,
            uint256 gasEstimate
        );

    /**
     * @notice Returns the required input amount to receive a desired exact output across multiple pools.
     * @dev Path must be provided in reverse (output → input).
     * @param path Encoded path of pools to simulate in reverse order.
     * @param amountOut Desired final output token amount.
     * @return amountIn Required amount of input token.
     * @return sqrtPriceX96AfterList List of sqrt prices after each simulated swap.
     * @return initializedTicksCrossedList Number of ticks crossed in each pool.
     * @return gasEstimate Estimated gas used for the full path.
     */
    function quoteExactOutput(bytes memory path, uint256 amountOut)
        external
        returns (
            uint256 amountIn,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksCrossedList,
            uint256 gasEstimate
        );

    /// @notice Parameters for quoting an exact output on a single pool.
    struct QuoteExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint256 amount;
        uint24 fee;
        uint160 sqrtPriceLimitX96;
    }

    /**
     * @notice Returns the required input amount to receive an exact output amount in a single pool swap.
     * @param params Struct with swap parameters: tokenIn, tokenOut, desired output, fee, and optional price limit.
     * @return amountIn Estimated required input.
     * @return sqrtPriceX96After Sqrt price after the simulated swap.
     * @return initializedTicksCrossed Number of ticks crossed during the swap.
     * @return gasEstimate Estimated gas used for the simulation.
     */
    function quoteExactOutputSingle(QuoteExactOutputSingleParams memory params)
        external
        returns (
            uint256 amountIn,
            uint160 sqrtPriceX96After,
            uint32 initializedTicksCrossed,
            uint256 gasEstimate
        );
}
