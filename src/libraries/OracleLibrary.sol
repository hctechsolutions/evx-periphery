// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@evx-core/libraries/FullMath.sol';
import '@evx-core/libraries/TickMath.sol';
import '@evx-core/interfaces/IEvxPool.sol';

/**
 * @title OracleLibrary
 * @notice Provides helper functions for interacting with Evx pool oracles.
 * @dev Includes logic to compute TWAP (time-weighted average price), quote calculations, and synthetic ticks.
 */
library OracleLibrary {
    /**
     * @notice Computes time-weighted average tick and harmonic mean liquidity for a given Evx pool.
     * @dev Uses the pool's internal observations to compute values over a time window.
     * @param pool The address of the Evx pool.
     * @param secondsAgo Time range in seconds to compute the average over (must be > 0).
     * @return arithmeticMeanTick The time-weighted average tick.
     * @return harmonicMeanLiquidity The harmonic mean liquidity.
     */
    function consult(address pool, uint32 secondsAgo)
        internal
        view
        returns (int24 arithmeticMeanTick, uint128 harmonicMeanLiquidity)
    {
        require(secondsAgo != 0, 'BP');

        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = secondsAgo;
        secondsAgos[1] = 0;

        (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s) =
            IEvxPool(pool).observe(secondsAgos);

        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        uint160 secondsPerLiquidityCumulativesDelta =
            secondsPerLiquidityCumulativeX128s[1] - secondsPerLiquidityCumulativeX128s[0];

        arithmeticMeanTick = int24(tickCumulativesDelta / int56(uint56(secondsAgo)));
        // Always round to negative infinity
        if (tickCumulativesDelta < 0 && (tickCumulativesDelta % int56(uint56(secondsAgo)) != 0)) arithmeticMeanTick--;

        // We are multiplying here instead of shifting to ensure that 
        // harmonicMeanLiquidity doesn't overflow uint128
        uint192 secondsAgoX160 = uint192(secondsAgo) * type(uint160).max;
        harmonicMeanLiquidity = uint128(secondsAgoX160 / (uint192(secondsPerLiquidityCumulativesDelta) << 32));
    }

    /**
     * @notice Computes a token quote for a given tick and base amount.
     * @dev Uses the sqrt ratio implied by the tick to determine the quote amount.
     * @param tick The tick at which to perform the quote.
     * @param baseAmount The amount of base token.
     * @param baseToken The address of the base token.
     * @param quoteToken The address of the quote token.
     * @return quoteAmount The amount of quote token that would be received.
     */
    function getQuoteAtTick(
        int24 tick,
        uint128 baseAmount,
        address baseToken,
        address quoteToken
    ) internal pure returns (uint256 quoteAmount) {
        uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(tick);

        // Calculate quoteAmount with better precision if it doesn't 
        // overflow when multiplied by itself
        if (sqrtRatioX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
            quoteAmount = baseToken < quoteToken
                ? FullMath.mulDiv(ratioX192, baseAmount, 1 << 192)
                : FullMath.mulDiv(1 << 192, baseAmount, ratioX192);
        } else {
            uint256 ratioX128 = FullMath.mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);
            quoteAmount = baseToken < quoteToken
                ? FullMath.mulDiv(ratioX128, baseAmount, 1 << 128)
                : FullMath.mulDiv(1 << 128, baseAmount, ratioX128);
        }
    }

    /**
     * @notice Gets the time in seconds since the oldest observation stored in the pool.
     * @param pool The address of the Evx pool.
     * @return secondsAgo Number of seconds ago of the oldest observation.
     */
    function getOldestObservationSecondsAgo(address pool) internal view returns (uint32 secondsAgo) {
        (, , uint16 observationIndex, uint16 observationCardinality, , , ) = IEvxPool(pool).slot0();
        require(observationCardinality > 0, 'NI');

        (uint32 observationTimestamp, , , bool initialized) =
            IEvxPool(pool).observations((observationIndex + 1) % observationCardinality);

        // The next index might not be initialized if the cardinality is in the process 
        // of increasing. In this case the oldest observation is always in index 0
        if (!initialized) {
            (observationTimestamp, , , ) = IEvxPool(pool).observations(0);
        }

        secondsAgo = uint32(block.timestamp) - observationTimestamp;
    }

    /**
     * @notice Gets the tick and liquidity value as of the start of the current block.
     * @dev Requires at least two observations in the pool to calculate.
     * @param pool The address of the Evx pool.
     * @return tick The tick at the beginning of the current block.
     * @return liquidity The pool liquidity at the beginning of the block.
     */
    function getBlockStartingTickAndLiquidity(address pool) internal view returns (int24, uint128) {
        (, int24 tick, uint16 observationIndex, uint16 observationCardinality, , , ) = IEvxPool(pool).slot0();

        // 2 observations are needed to reliably calculate the block starting tick
        require(observationCardinality > 1, 'NEO');

        // If the latest observation occurred in the past, then no tick-changing 
        // trades have happened in this block therefore the tick in `slot0` is 
        // the same as at the beginning of the current block. We don't need to 
        // check if this observation is initialized - it is guaranteed to be.
        (uint32 observationTimestamp, int56 tickCumulative, uint160 secondsPerLiquidityCumulativeX128, ) =
            IEvxPool(pool).observations(observationIndex);
        if (observationTimestamp != uint32(block.timestamp)) {
            return (tick, IEvxPool(pool).liquidity());
        }

        uint256 prevIndex = (uint256(observationIndex) + observationCardinality - 1) % observationCardinality;
        (
            uint32 prevObservationTimestamp,
            int56 prevTickCumulative,
            uint160 prevSecondsPerLiquidityCumulativeX128,
            bool prevInitialized
        ) = IEvxPool(pool).observations(prevIndex);

        require(prevInitialized, 'ONI');

        uint32 delta = observationTimestamp - prevObservationTimestamp;
        tick = int24((tickCumulative - prevTickCumulative) / int56(uint56(delta)));
        uint128 liquidity =
            uint128(
                (uint192(delta) * type(uint160).max) /
                    (uint192(secondsPerLiquidityCumulativeX128 - prevSecondsPerLiquidityCumulativeX128) << 32)
            );
        return (tick, liquidity);
    }

    /**
     * @notice A struct representing a weighted tick observation for aggregation.
     * @dev Used in weighted average tick calculations.
     * @param tick The tick value.
     * @param weight The associated weight for averaging.
     */
    struct WeightedTickData {
        int24 tick;
        uint128 weight;
    }

    /**
     * @notice Computes the weighted arithmetic mean of a series of ticks.
     * @dev Rounds toward negative infinity in case of division with remainder.
     * @param weightedTickData Array of ticks and corresponding weights.
     * @return weightedArithmeticMeanTick The resulting weighted mean tick.
     */
    function getWeightedArithmeticMeanTick(WeightedTickData[] memory weightedTickData)
        internal
        pure
        returns (int24 weightedArithmeticMeanTick)
    {
        // Accumulates the sum of products between each tick and its weight
        int256 numerator;

        // Accumulates the sum of the weights
        uint256 denominator;

        // Products fit in 152 bits, so it would take an array of length ~2**104 to overflow this logic
        for (uint256 i; i < weightedTickData.length; i++) {
            numerator += weightedTickData[i].tick * int256(uint256(weightedTickData[i].weight));
            denominator += weightedTickData[i].weight;
        }

        weightedArithmeticMeanTick = int24(numerator / int256(denominator));
        // Always round to negative infinity
        if (numerator < 0 && (numerator % int256(denominator) != 0)) weightedArithmeticMeanTick--;
    }

    /**
     * @notice Computes a synthetic tick across a token route based on intermediate ticks.
     * @dev Useful for calculating effective prices across swap routes.
     * @param tokens Array of token addresses in the route.
     * @param ticks Array of ticks corresponding to adjacent token pairs.
     * @return syntheticTick The net tick representing the entire route.
     */
    function getChainedPrice(address[] memory tokens, int24[] memory ticks)
        internal
        pure
        returns (int256 syntheticTick)
    {
        require(tokens.length - 1 == ticks.length, 'DL');
        for (uint256 i = 1; i <= ticks.length; i++) {
            // Check the tokens for address sort order, then accumulate the
            // ticks into the running synthetic tick, ensuring that intermediate tokens "cancel out"
            tokens[i - 1] < tokens[i] ? syntheticTick += ticks[i - 1] : syntheticTick -= ticks[i - 1];
        }
    }
}
