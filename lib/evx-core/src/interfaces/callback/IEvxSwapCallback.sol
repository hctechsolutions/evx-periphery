// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IEvxSwapCallback
 * @notice Interface for contracts that perform token swaps via IEvxPoolActions#swap.
 * @dev Implementers must handle settlement by sending owed tokens to the pool during the callback.
 */
interface IEvxSwapCallback {
    /**
     * @notice Callback invoked by an EvxPool after executing a token swap.
     * @dev The caller must transfer the required amounts of token0 and/or token1 to the pool, if applicable.
     *      The caller must be verified to be a valid EvxPool deployed by the canonical EvxFactory.
     *      If either delta is positive, that token must be sent to the pool.
     * @param amount0Delta The net change in token0 (positive = must be paid to the pool, negative = received).
     * @param amount1Delta The net change in token1 (positive = must be paid to the pool, negative = received).
     * @param data Arbitrary data passed through from the original swap call.
     */
    function evxSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}
