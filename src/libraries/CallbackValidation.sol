// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@evx-core/interfaces/IEvxPool.sol';
import './PoolAddress.sol';

/**
 * @title CallbackValidation
 * @notice Provides validation logic for ensuring that function calls originate from legitimate Evx Pools.
 * @dev This library is used to securely verify the sender of a callback is a valid deployed Evx Pool.
 */
library CallbackValidation {
    /**
     * @notice Verifies the validity of a callback using token addresses and fee.
     * @dev Computes the pool key and delegates to the overloaded verifyCallback function.
     *      Reverts if the caller is not the expected Evx Pool address.
     * @param factory The address of the Evx factory contract.
     * @param tokenA The address of one of the tokens in the pool.
     * @param tokenB The address of the other token in the pool.
     * @param fee The fee tier of the pool, in hundredths of a bip (1e-6).
     * @return pool The Evx Pool contract that matches the provided parameters.
     */
    function verifyCallback(
        address factory,
        address tokenA,
        address tokenB,
        uint24 fee
    ) internal view returns (IEvxPool pool) {
        return verifyCallback(factory, PoolAddress.getPoolKey(tokenA, tokenB, fee));
    }

    /**
     * @notice Verifies the validity of a callback using a PoolKey.
     * @dev Computes the expected pool address and checks that the caller matches it.
     *      Reverts if the caller is not the expected Evx Pool.
     * @param factory The address of the Evx factory contract.
     * @param poolKey The key struct that uniquely identifies a Evx Pool.
     * @return pool The Evx Pool contract corresponding to the provided poolKey.
     */
    function verifyCallback(address factory, PoolAddress.PoolKey memory poolKey)
        internal
        view
        returns (IEvxPool pool)
    {
        pool = IEvxPool(PoolAddress.computeAddress(factory, poolKey));
        require(msg.sender == address(pool), 'CallbackValidation: INVALID_SENDER');
    }
}
