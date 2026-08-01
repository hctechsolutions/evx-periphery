// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Pool state that can change
 * @notice Exposes dynamic pool state variables and mappings for liquidity, ticks, positions, and observations
 * @dev State may change multiple times per transaction; slot0 packs common data for gas efficiency
 */
interface IEvxPoolState {
    /**
     * @notice The 0th storage slot in the pool stores multiple values in a single SLOAD
     * @return sqrtPriceX96 The current sqrt(token1/token0) price of the pool as a Q64.96
     * @return tick The current tick of the pool (may differ from getTickAtSqrtRatio at boundaries)
     * @return observationIndex Index of the last oracle observation written
     * @return observationCardinality Maximum number of observations stored
     * @return observationCardinalityNext Next observation cardinality to be applied upon write
     * @return feeProtocol The protocol fee for both tokens, encoded as two 4-bit values (token0 lower 4 bits, token1 upper 4 bits)
     * @return unlocked Whether the pool is currently unlocked for reentrancy
     */
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );

    /**
     * @notice The fee growth as a Q128.128 value of token0 collected per unit of liquidity for the entire life of the pool
     * @dev May overflow uint256 and wrap around
     * @return The fee growth of token0 globally
     */
    function feeGrowthGlobal0X128() external view returns (uint256);

    /**
     * @notice The fee growth as a Q128.128 value of token1 collected per unit of liquidity for the entire life of the pool
     * @dev May overflow uint256 and wrap around
     * @return The fee growth of token1 globally
     */
    function feeGrowthGlobal1X128() external view returns (uint256);

    /**
     * @notice The amounts of token0 and token1 owed to the protocol
     * @dev Values will never exceed uint128 max for each token
     * @return token0 The accrued protocol fees in token0
     * @return token1 The accrued protocol fees in token1
     */
    function protocolFees() external view returns (uint128 token0, uint128 token1);

    /**
     * @notice The currently in-range liquidity available to the pool
     * @dev This is not the total across all ticks, only liquidity within the current range
     * @return The in-range liquidity
     */
    function liquidity() external view returns (uint128);

    /**
     * @notice Look up information about a specific tick in the pool
     * @param tick The tick to query
     * @return liquidityGross Total position liquidity that references this tick
     * @return liquidityNet Net change in liquidity when crossing this tick
     * @return feeGrowthOutside0X128 Fee growth of token0 outside this tick
     * @return feeGrowthOutside1X128 Fee growth of token1 outside this tick
     * @return tickCumulativeOutside Cumulative tick outside this tick
     * @return secondsPerLiquidityOutsideX128 Seconds per liquidity outside this tick
     * @return secondsOutside Seconds spent outside this tick
     * @return initialized True if the tick is initialized (liquidityGross > 0)
     */
    function ticks(int24 tick)
        external
        view
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128,
            int56 tickCumulativeOutside,
            uint160 secondsPerLiquidityOutsideX128,
            uint32 secondsOutside,
            bool initialized
        );

    /**
     * @notice Returns 256 packed tick initialized boolean values
     * @param wordPosition The position of the 256-bit word in the tick bitmap
     * @return A uint256 with each bit representing tick initialization
     */
    function tickBitmap(int16 wordPosition) external view returns (uint256);

    /**
     * @notice Returns information about a position by its key
     * @param key The position key (hash of owner, tickLower, tickUpper)
     * @return _liquidity The amount of liquidity in the position
     * @return feeGrowthInside0LastX128 Fee growth of token0 inside the range as of last update
     * @return feeGrowthInside1LastX128 Fee growth of token1 inside the range as of last update
     * @return tokensOwed0 Computed amount of token0 owed to the position
     * @return tokensOwed1 Computed amount of token1 owed to the position
     */
    function positions(bytes32 key)
        external
        view
        returns (
            uint128 _liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    /**
     * @notice Returns data about a specific oracle observation
     * @param index The index in the observations array to retrieve
     * @dev Prefer using #observe for time-based queries instead of direct index access
     * @return blockTimestamp The timestamp of the observation
     * @return tickCumulative The tick accumulator at the observation timestamp
     * @return secondsPerLiquidityCumulativeX128 Seconds per in-range liquidity accumulator at the timestamp
     * @return initialized Whether the observation entry has been initialized
     */
    function observations(uint256 index)
        external
        view
        returns (
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint160 secondsPerLiquidityCumulativeX128,
            bool initialized
        );
}