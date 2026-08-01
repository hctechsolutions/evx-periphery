// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPoolInitializer
 * @notice Interface for creating and initializing Evx pools.
 * @dev Designed to be used with multicall or atomic setup operations like mint.
 */
interface IPoolInitializer {
    /**
     * @notice Creates a new pool for a token pair and fee tier if it doesn't exist, and initializes it if not initialized.
     * @dev Can be composed with other calls (e.g., mint) to ensure the pool is ready in a single transaction.
     *
     * @param token0 Address of token0 (must be lexicographically smaller than token1).
     * @param token1 Address of token1 (must be lexicographically greater than token0).
     * @param fee Fee tier of the pool, expressed in hundredths of a bip (1e-6).
     * @param sqrtPriceX96 The initial sqrt price of the pool encoded as a Q64.96 value.
     * @return pool The address of the existing or newly created and initialized pool.
     */
    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external payable returns (address pool);
}
