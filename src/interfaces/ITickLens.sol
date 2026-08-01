// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ITickLens
 * @notice Interface for retrieving detailed tick data from Evx pools.
 * @dev Designed to efficiently extract tick states by parsing a specific word of the tick bitmap.
 * Also provides utilities for converting price ranges to ticks.
 */
interface ITickLens {
    /**
     * @notice Struct representing a single initialized tick with its liquidity state.
     * @param tick The index of the initialized tick.
     * @param liquidityNet Net liquidity change when crossing this tick.
     * @param liquidityGross Total liquidity provisioned at this tick.
     */
    struct PopulatedTick {
        int24 tick;
        int128 liquidityNet;
        uint128 liquidityGross;
    }

    /**
     * @notice Retrieves all initialized ticks in a given 256-bit word from a pool's tick bitmap.
     * @dev Saves gas and complexity by batching tick queries through bitmap decoding.
     * @param pool Address of the Evx pool.
     * @param tickBitmapIndex Index of the 256-bit word in the pool's tick bitmap to scan.
     * @return populatedTicks Array of initialized ticks and their liquidity data.
     */
    function getPopulatedTicksInWord(address pool, int16 tickBitmapIndex)
        external
        view
        returns (PopulatedTick[] memory populatedTicks);
        
    /**
     * @notice Converts a price range to tick lower and tick upper values
     * @dev Uses existing Evx core libraries for accurate calculations
     * @param pool The Evx pool address
     * @param sqrtPriceLowerX96 The lower sqrt price in X96 format
     * @param sqrtPriceUpperX96 The upper sqrt price in X96 format
     * @return tickLower The calculated tick lower value
     * @return tickUpper The calculated tick upper value
     */
    function getTicksFromPriceRange(
        address pool,
        uint160 sqrtPriceLowerX96,
        uint160 sqrtPriceUpperX96
    ) external view returns (int24 tickLower, int24 tickUpper);
    

}
