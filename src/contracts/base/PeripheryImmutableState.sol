// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@evx-core/interfaces/IEvxFactory.sol';
import '@evx-periphery/interfaces/IPeripheryImmutableState.sol';

/**
 * @title PeripheryImmutableState
 * @notice Immutable state used by periphery contracts.
 * @dev Stores factory and WETH9 addresses set at deployment.
 */
abstract contract PeripheryImmutableState is IPeripheryImmutableState {
    /// @notice Factory is missing code or has no pool implementation.
    error InvalidFactory();

    /// @inheritdoc IPeripheryImmutableState
    address public immutable override factory;

    /// @inheritdoc IPeripheryImmutableState
    address public immutable override WETH9;

    /**
     * @notice Sets immutable factory and WETH9 addresses.
     * @dev Reverts unless `factory` is a deployed contract whose pool
     *      implementation is set. That address is immutable on EvxFactory.
     * @param _factory The address of the EvxFactory contract.
     * @param _WETH9 The address of the WETH9 contract.
     */
    constructor(address _factory, address _WETH9) {
        if (_factory.code.length == 0 || IEvxFactory(_factory).poolImplementation() == address(0)) {
            revert InvalidFactory();
        }
        factory = _factory;
        WETH9 = _WETH9;
    }
}
