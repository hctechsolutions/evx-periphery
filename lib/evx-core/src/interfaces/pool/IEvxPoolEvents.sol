// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Events emitted by a pool
 * @notice Contains all events emitted by the pool for tracking state changes and interactions
 */
interface IEvxPoolEvents {
    /**
     * @notice Emitted exactly once by a pool when #initialize is first called on the pool
     * @dev Mint, Burn, and Swap cannot be emitted before Initialize. Represents initial setup of price and tick.
     * @param sqrtPriceX96 The initial sqrt price of the pool as a Q64.96 value
     * @param tick The initial tick of the pool (log base 1.0001 of the starting price)
     */
    event InitializeObservation(uint160 sqrtPriceX96, int24 tick);

    /**
     * @notice Emitted when liquidity is minted for a given position
     * @param sender The address that minted the liquidity
     * @param owner The owner of the position and recipient of any minted liquidity
     * @param tickLower The lower tick boundary of the position
     * @param tickUpper The upper tick boundary of the position
     * @param amount The amount of liquidity minted
     * @param amount0 The amount of token0 required for the minted liquidity
     * @param amount1 The amount of token1 required for the minted liquidity
     */
    event Mint(
        address sender,
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /**
     * @notice Emitted when fees are collected by the owner of a position
     * @dev May be emitted with zero amounts if caller chooses not to collect
     * @param owner The owner of the position for which fees are collected
     * @param recipient The address that receives the collected fees
     * @param tickLower The lower tick boundary of the position
     * @param tickUpper The upper tick boundary of the position
     * @param amount0 The amount of token0 fees collected
     * @param amount1 The amount of token1 fees collected
     */
    event Collect(
        address indexed owner,
        address recipient,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount0,
        uint128 amount1
    );

    /**
     * @notice Emitted when a position's liquidity is removed (burned)
     * @dev Does not withdraw fees, which must be collected separately via #collect
     * @param owner The owner of the position
     * @param tickLower The lower tick boundary of the position
     * @param tickUpper The upper tick boundary of the position
     * @param amount The amount of liquidity removed
     * @param amount0 The amount of token0 withdrawn
     * @param amount1 The amount of token1 withdrawn
     */
    event Burn(
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /**
     * @notice Emitted by the pool for any swaps between token0 and token1
     * @param sender The address that initiated the swap and received the callback
     * @param recipient The address that received the output of the swap
     * @param amount0 The delta of token0 balance of the pool (exact when negative, minimum when positive)
     * @param amount1 The delta of token1 balance of the pool (exact when negative, minimum when positive)
     * @param sqrtPriceX96 The sqrt(price) of the pool after the swap as a Q64.96 value
     * @param liquidity The liquidity of the pool after the swap
     * @param tick The tick of the pool after the swap (log base 1.0001 of price)
     */
    event Swap(
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    /**
     * @notice Emitted by the pool for any flashes of token0/token1
     * @param sender The address that initiated the flash and received the callback
     * @param recipient The address that received the flashed tokens
     * @param amount0 The amount of token0 that was flashed
     * @param amount1 The amount of token1 that was flashed
     * @param paid0 The amount of token0 paid back (may exceed amount0 plus fee)
     * @param paid1 The amount of token1 paid back (may exceed amount1 plus fee)
     */
    event Flash(
        address indexed sender,
        address indexed recipient,
        uint256 amount0,
        uint256 amount1,
        uint256 paid0,
        uint256 paid1
    );

    /**
     * @notice Emitted when the maximum number of stored observations is increased
     * @dev observationCardinalityNext is applied on the next write after this event
     * @param observationCardinalityNextOld The previous target number of observations
     * @param observationCardinalityNextNew The new target number of observations
     */
    event IncreaseObservationCardinalityNext(
        uint16 observationCardinalityNextOld,
        uint16 observationCardinalityNextNew
    );

    /**
     * @notice Emitted when the protocol fee is changed by the pool
     * @param feeProtocol0Old The previous token0 protocol fee
     * @param feeProtocol1Old The previous token1 protocol fee
     * @param feeProtocol0New The updated token0 protocol fee
     * @param feeProtocol1New The updated token1 protocol fee
     */
    event SetFeeProtocol(
        uint8 feeProtocol0Old,
        uint8 feeProtocol1Old,
        uint8 feeProtocol0New,
        uint8 feeProtocol1New
    );

    /**
     * @notice Emitted when the collected protocol fees are withdrawn by the factory owner
     * @param sender The address that collects the protocol fees
     * @param recipient The address that receives the collected protocol fees
     * @param amount0 The amount of token0 protocol fees withdrawn
     * @param amount1 The amount of token1 protocol fees withdrawn
     */
    event CollectProtocol(
        address indexed sender,
        address indexed recipient,
        uint128 amount0,
        uint128 amount1
    );
}