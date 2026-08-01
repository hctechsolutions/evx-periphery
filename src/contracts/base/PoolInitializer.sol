// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@evx-core/interfaces/IEvxFactory.sol';
import '@evx-core/interfaces/IEvxPool.sol';

import './PeripheryImmutableState.sol';
import '@evx-periphery/interfaces/IPoolInitializer.sol';

/**
 * @title PoolInitializer
 * @notice Creates and initializes Evx pools if it do not exist.
 * @dev Relies on the EvxFactory for pool management.
 */
abstract contract PoolInitializer is IPoolInitializer, PeripheryImmutableState {
    /// @inheritdoc IPoolInitializer
    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external payable override returns (address pool) {
        require(token0 < token1);
        pool = IEvxFactory(factory).getPool(token0, token1, fee);

        if (pool == address(0)) {
            pool = IEvxFactory(factory).createPool(token0, token1, fee);
            IEvxPool(pool).initializeObservation(sqrtPriceX96);
        } else {
            (uint160 sqrtPriceX96Existing, , , , , , ) = IEvxPool(pool).slot0();
            if (sqrtPriceX96Existing == 0) {
                IEvxPool(pool).initializeObservation(sqrtPriceX96);
            }
        }
    }
}
