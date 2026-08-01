// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LowGasSafeMath.sol";
import "./SafeCast.sol";

import "./TickMath.sol";
import "./LiquidityMath.sol";

/**
 * @title Tick
 * @notice Library for managing tick data and associated calculations in a liquidity pool.
 */
library Tick {
    using LowGasSafeMath for int256;
    using SafeCast for int256;

    /**
     * @notice Structure representing all state associated with a tick.
     */
    struct Info {
        /// @notice Total position liquidity referencing this tick.
        uint128 liquidityGross;

        /// @notice Net liquidity change when crossing this tick from left to right.
        int128 liquidityNet;

        /// @notice Cumulative fee growth on the opposite side of this tick for token0.
        uint256 feeGrowthOutside0X128;

        /// @notice Cumulative fee growth on the opposite side of this tick for token1.
        uint256 feeGrowthOutside1X128;

        /// @notice Cumulative tick value outside this tick.
        int56 tickCumulativeOutside;

        /// @notice Seconds per unit of liquidity outside this tick.
        uint160 secondsPerLiquidityOutsideX128;

        /// @notice Time spent outside this tick.
        uint32 secondsOutside;

        /// @notice Whether the tick is initialized (i.e., has non-zero liquidityGross).
        bool initialized;
    }

    /**
     * @notice Computes the maximum liquidity per tick for a given spacing.
     * @param tickSpacing The spacing between usable ticks.
     * @return The maximum liquidity that can be assigned to a single tick.
     */
    function tickSpacingToMaxLiquidityPerTick(int24 tickSpacing) internal pure returns (uint128) {
        int24 minTick = (TickMath.MIN_TICK / tickSpacing) * tickSpacing;
        int24 maxTick = (TickMath.MAX_TICK / tickSpacing) * tickSpacing;
        uint24 numTicks = uint24((maxTick - minTick) / tickSpacing) + 1;
        return type(uint128).max / numTicks;
    }

    /**
     * @notice Calculates the fee growth inside a position's tick range.
     * @param self Mapping of tick info.
     * @param tickLower The lower bound of the position.
     * @param tickUpper The upper bound of the position.
     * @param tickCurrent The current pool tick.
     * @param feeGrowthGlobal0X128 Global fee growth for token0.
     * @param feeGrowthGlobal1X128 Global fee growth for token1.
     * @return feeGrowthInside0X128 Fee growth for token0 inside the position.
     * @return feeGrowthInside1X128 Fee growth for token1 inside the position.
     */
    function getFeeGrowthInside(
        mapping(int24 => Tick.Info) storage self,
        int24 tickLower,
        int24 tickUpper,
        int24 tickCurrent,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    ) internal view returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) {
        Info storage lower = self[tickLower];
        Info storage upper = self[tickUpper];

        // calculate fee growth below
        uint256 feeGrowthBelow0X128;
        uint256 feeGrowthBelow1X128;
        if (tickCurrent >= tickLower) {
            feeGrowthBelow0X128 = lower.feeGrowthOutside0X128;
            feeGrowthBelow1X128 = lower.feeGrowthOutside1X128;
        } else {
            feeGrowthBelow0X128 = feeGrowthGlobal0X128 - lower.feeGrowthOutside0X128;
            feeGrowthBelow1X128 = feeGrowthGlobal1X128 - lower.feeGrowthOutside1X128;
        }

        // calculate fee growth above
        uint256 feeGrowthAbove0X128;
        uint256 feeGrowthAbove1X128;
        if (tickCurrent < tickUpper) {
            feeGrowthAbove0X128 = upper.feeGrowthOutside0X128;
            feeGrowthAbove1X128 = upper.feeGrowthOutside1X128;
        } else {
            feeGrowthAbove0X128 = feeGrowthGlobal0X128 - upper.feeGrowthOutside0X128;
            feeGrowthAbove1X128 = feeGrowthGlobal1X128 - upper.feeGrowthOutside1X128;
        }

        feeGrowthInside0X128 = feeGrowthGlobal0X128 - feeGrowthBelow0X128 - feeGrowthAbove0X128;
        feeGrowthInside1X128 = feeGrowthGlobal1X128 - feeGrowthBelow1X128 - feeGrowthAbove1X128;
    }

    /**
     * @notice Updates the state of a given tick and returns whether it was flipped.
     * @param self Mapping of tick info.
     * @param tick The tick index to update.
     * @param tickCurrent The current tick of the pool.
     * @param liquidityDelta Change in liquidity at this tick.
     * @param feeGrowthGlobal0X128 Global fee growth for token0.
     * @param feeGrowthGlobal1X128 Global fee growth for token1.
     * @param secondsPerLiquidityCumulativeX128 Seconds per liquidity value.
     * @param tickCumulative The cumulative tick value.
     * @param time Current block timestamp.
     * @param upper Whether this is the upper tick of a position.
     * @param maxLiquidity Maximum allowed liquidity per tick.
     * @return flipped True if the tick was initialized or de-initialized.
     */
    function update(
        mapping(int24 => Tick.Info) storage self,
        int24 tick,
        int24 tickCurrent,
        int128 liquidityDelta,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128,
        uint160 secondsPerLiquidityCumulativeX128,
        int56 tickCumulative,
        uint32 time,
        bool upper,
        uint128 maxLiquidity
    ) internal returns (bool flipped) {
        Tick.Info storage info = self[tick];

        uint128 liquidityGrossBefore = info.liquidityGross;
        uint128 liquidityGrossAfter = LiquidityMath.addDelta(liquidityGrossBefore, liquidityDelta);

        require(liquidityGrossAfter <= maxLiquidity, 'LO');

        flipped = (liquidityGrossAfter == 0) != (liquidityGrossBefore == 0);

        if (liquidityGrossBefore == 0) {
            // by convention, we assume that all growth before a tick was initialized happened _below_ the tick
            if (tick <= tickCurrent) {
                info.feeGrowthOutside0X128 = feeGrowthGlobal0X128;
                info.feeGrowthOutside1X128 = feeGrowthGlobal1X128;
                info.secondsPerLiquidityOutsideX128 = secondsPerLiquidityCumulativeX128;
                info.tickCumulativeOutside = tickCumulative;
                info.secondsOutside = time;
            }
            info.initialized = true;
        }

        info.liquidityGross = liquidityGrossAfter;

        // when the lower (upper) tick is crossed left to right (right to left), liquidity must be added (removed)
        info.liquidityNet = upper
            ? int256(info.liquidityNet).sub(liquidityDelta).toInt128()
            : int256(info.liquidityNet).add(liquidityDelta).toInt128();
    }

    /**
     * @notice Clears all state for a tick.
     * @param self Mapping of tick info.
     * @param tick The tick index to clear.
     */
    function clear(mapping(int24 => Tick.Info) storage self, int24 tick) internal {
        delete self[tick];
    }

    /**
     * @notice Called when the pool's price crosses a tick.
     * @param self Mapping of tick info.
     * @param tick The tick being crossed.
     * @param feeGrowthGlobal0X128 Global fee growth for token0.
     * @param feeGrowthGlobal1X128 Global fee growth for token1.
     * @param secondsPerLiquidityCumulativeX128 Global seconds per liquidity.
     * @param tickCumulative The cumulative tick value.
     * @param time The current timestamp.
     * @return liquidityNet The liquidity change from crossing this tick.
     */
    function cross(
        mapping(int24 => Tick.Info) storage self,
        int24 tick,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128,
        uint160 secondsPerLiquidityCumulativeX128,
        int56 tickCumulative,
        uint32 time
    ) internal returns (int128 liquidityNet) {
        Tick.Info storage info = self[tick];
        info.feeGrowthOutside0X128 = feeGrowthGlobal0X128 - info.feeGrowthOutside0X128;
        info.feeGrowthOutside1X128 = feeGrowthGlobal1X128 - info.feeGrowthOutside1X128;
        info.secondsPerLiquidityOutsideX128 = secondsPerLiquidityCumulativeX128 - info.secondsPerLiquidityOutsideX128;
        info.tickCumulativeOutside = tickCumulative - info.tickCumulativeOutside;
        info.secondsOutside = time - info.secondsOutside;
        liquidityNet = info.liquidityNet;
    }
}
