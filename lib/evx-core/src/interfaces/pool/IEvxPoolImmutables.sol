// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Pool state that never changes
 * @notice These parameters are fixed for a pool forever; the methods will always return the same values
 */
interface IEvxPoolImmutables {
    /**
     * @notice Returns the contract that deployed the pool
     * @dev The deployer must adhere to the IEvxFactory interface
     * @return The factory contract address
     */
    function factory() external view returns (address);

    /**
     * @notice Returns the first of the two tokens of the pool, sorted by address
     * @return The token0 contract address
     */
    function token0() external view returns (address);

    /**
     * @notice Returns the second of the two tokens of the pool, sorted by address
     * @return The token1 contract address
     */
    function token1() external view returns (address);

    /**
     * @notice Returns the pool's fee in hundredths of a bip
     * @dev Represented as 1e-6 of the swap amount
     * @return The fee tier
     */
    function fee() external view returns (uint24);

    /**
     * @notice Returns the pool tick spacing
     * @dev Ticks can only be initialized at multiples of this value; minimum of 1 and always positive
     *      For example, a tickSpacing of 3 allows ticks at ..., -6, -3, 0, 3, 6, ...
     * @return The tick spacing as an int24
     */
    function tickSpacing() external view returns (int24);

    /**
     * @notice Returns the maximum amount of position liquidity that can use any tick in the range
     * @dev Enforced per tick to prevent overflow of uint128 and to restrict out-of-range liquidity
     * @return The max liquidity per tick
     */
    function maxLiquidityPerTick() external view returns (uint128);
}
