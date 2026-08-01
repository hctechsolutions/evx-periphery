// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@evx-core/interfaces/IEvxPool.sol';
import '@evx-core/libraries/TickMath.sol';
import '@evx-periphery/interfaces/ITickLens.sol';

/**
 * @title TickLens
 * @notice Utility contract to retrieve detailed tick information from a Evx pool.
 * @dev Reads the tick bitmap and tick data for a specific word (256-bit section).
 * Also provides utilities for converting price ranges to ticks.
 */
contract TickLens is ITickLens {
    /// @inheritdoc ITickLens
    function getPopulatedTicksInWord(address pool, int16 tickBitmapIndex)
        public
        view
        override
        returns (PopulatedTick[] memory populatedTicks)
    {
        // Fetch bitmap
        uint256 bitmap = IEvxPool(pool).tickBitmap(tickBitmapIndex);

        // Calculate the number of populated ticks
        uint256 numberOfPopulatedTicks;
        for (uint256 i = 0; i < 256; i++) {
            if ((bitmap & (1 << i)) > 0) numberOfPopulatedTicks++;
        }

        // fetch populated tick data
        int24 tickSpacing = IEvxPool(pool).tickSpacing();
        populatedTicks = new PopulatedTick[](numberOfPopulatedTicks);
        for (uint256 i = 0; i < 256; i++) {
            if ((bitmap & (1 << i)) > 0) {
                int24 populatedTick = int24((int256(tickBitmapIndex) << 8) + int256(int8(uint8(i)))) * tickSpacing;
                (uint128 liquidityGross, int128 liquidityNet, , , , , , ) = IEvxPool(pool).ticks(populatedTick);
                populatedTicks[--numberOfPopulatedTicks] = PopulatedTick({
                    tick: populatedTick,
                    liquidityNet: liquidityNet,
                    liquidityGross: liquidityGross
                });
            }
        }
    }

    /// @inheritdoc ITickLens
    function getTicksFromPriceRange(
        address pool,
        uint160 sqrtPriceLowerX96,
        uint160 sqrtPriceUpperX96
    ) external view override returns (int24 tickLower, int24 tickUpper) {
        require(sqrtPriceLowerX96 < sqrtPriceUpperX96, "Price lower must be less than price upper");
        require(sqrtPriceLowerX96 > 0 && sqrtPriceUpperX96 > 0, "Prices must be positive");
        
        // Get tick spacing from the pool
        int24 tickSpacing = IEvxPool(pool).tickSpacing();
        
        // Convert sqrt prices to ticks
        tickLower = TickMath.getTickAtSqrtRatio(sqrtPriceLowerX96);
        tickUpper = TickMath.getTickAtSqrtRatio(sqrtPriceUpperX96);
        
        // Ensure ticks are properly spaced
        tickLower = (tickLower / tickSpacing) * tickSpacing; // Round down for lower
        tickUpper = ((tickUpper + tickSpacing - 1) / tickSpacing) * tickSpacing; // Round up for upper
        
        // Ensure we don't exceed tick bounds
        int24 minTick = (TickMath.MIN_TICK / tickSpacing) * tickSpacing;
        int24 maxTick = (TickMath.MAX_TICK / tickSpacing) * tickSpacing;
        
        if (tickLower < minTick) tickLower = minTick;
        if (tickUpper > maxTick) tickUpper = maxTick;
    }
}
