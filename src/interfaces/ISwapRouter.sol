// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@evx-core/interfaces/callback/IEvxSwapCallback.sol';

/**
 * @title ISwapRouter
 * @notice Stateless router interface for executing token swaps using Evx pools.
 * @dev Supports both exact input and exact output modes, with optional multi-hop routing.
 */
interface ISwapRouter is IEvxSwapCallback {
    /**
     * @notice Parameters for performing a single pool exact input swap.
     * @param tokenIn Address of the token being swapped in.
     * @param tokenOut Address of the token being swapped out.
     * @param fee Fee tier of the target pool.
     * @param recipient Address receiving the output tokens.
     * @param deadline Transaction must be mined before this timestamp.
     * @param amountIn Amount of input token to send.
     * @param amountOutMinimum Minimum acceptable amount of output token.
     * @param sqrtPriceLimitX96 Optional price limit for slippage protection.
     */
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /**
     * @notice Executes a single pool swap from `tokenIn` to `tokenOut` using exact input.
     * @param params Struct containing all swap parameters.
     * @return amountOut The amount of `tokenOut` received from the swap.
     */
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    /**
     * @notice Parameters for a multi-hop exact input swap.
     * @param path Encoded sequence of pools to swap through (tokenIn, fee, tokenOut,...).
     * @param recipient Address receiving the final output tokens.
     * @param deadline Timestamp by which the transaction must be confirmed.
     * @param amountIn Total input amount.
     * @param amountOutMinimum Minimum amount of final output tokens.
     */
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /**
     * @notice Executes a multi-hop swap to get the maximum possible output from a fixed input.
     * @param params Struct containing the encoded path and amounts.
     * @return amountOut Final amount of output token received.
     */
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

    /**
     * @notice Parameters for performing a single pool exact output swap.
     * @param tokenIn Address of the token being swapped in.
     * @param tokenOut Address of the token being swapped out.
     * @param fee Fee tier of the target pool.
     * @param recipient Address receiving the output tokens.
     * @param deadline Transaction must be mined before this timestamp.
     * @param amountOut Exact amount of output tokens desired.
     * @param amountInMaximum Maximum input amount willing to spend.
     * @param sqrtPriceLimitX96 Optional price limit to avoid excessive slippage.
     */
    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    /**
     * @notice Executes a single pool swap to obtain an exact output amount.
     * @param params Struct containing all swap parameters.
     * @return amountIn The amount of `tokenIn` spent to obtain `amountOut`.
     */
    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);

    /**
     * @notice Parameters for a multi-hop exact output swap.
     * @param path Encoded sequence of pools in reverse (tokenOut → tokenIn).
     * @param recipient Address receiving the final output tokens.
     * @param deadline Transaction must be mined before this timestamp.
     * @param amountOut Exact amount of output tokens desired.
     * @param amountInMaximum Maximum total input amount allowed.
     */
    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    /**
     * @notice Executes a multi-hop swap to receive an exact amount of output.
     * @param params Struct with encoded path, output target, and max input.
     * @return amountIn The total input tokens spent to achieve the exact output.
     */
    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);
}
