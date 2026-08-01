// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Pool state that is not stored
 * @notice Contains view functions to provide information about the pool that is computed rather than stored on-chain
 * @dev Functions here may have variable gas costs and compute values like time-weighted averages
 */
interface IEvxPoolDerivedState {
    /**
     * @notice Returns the cumulative tick and liquidity as of each timestamp `secondsAgo` from the current block timestamp
     * @dev To compute time-weighted averages, call with two values: one for period start and one for period end, e.g., [3600, 0]
     * @dev Cumulative tick is the geometric time-weighted average price in log base sqrt(1.0001) of token1/token0.
     *      Use TickMath to convert tick values to price ratios.
     * @param secondsAgos An array of time offsets (in seconds) ago from the current block timestamp
     * @return tickCumulatives Cumulative tick values at each `secondsAgos` offset
     * @return secondsPerLiquidityCumulativeX128s Cumulative seconds per liquidity-in-range at each `secondsAgos` offset
     */
    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);

    /**
     * @notice Returns a snapshot of tick cumulative, seconds per liquidity, and seconds inside a tick range
     * @dev Snapshots must only be compared over periods when a position exists for the entire interval
     * @param tickLower The lower tick boundary of the range
     * @param tickUpper The upper tick boundary of the range
     * @return tickCumulativeInside The tick accumulator snapshot for the specified range
     * @return secondsPerLiquidityInsideX128 The seconds per liquidity-in-range snapshot for the range
     * @return secondsInside The total seconds the pool was in range for the specified range
     */
    function snapshotCumulativesInside(int24 tickLower, int24 tickUpper)
        external
        view
        returns (
            int56 tickCumulativeInside,
            uint160 secondsPerLiquidityInsideX128,
            uint32 secondsInside
        );
}
