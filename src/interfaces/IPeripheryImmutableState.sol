// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPeripheryImmutableState
 * @notice Interface for accessing immutable deployment parameters in periphery contracts.
 * @dev Used to expose core addresses like the factory and WETH9 configured at construction.
 */
interface IPeripheryImmutableState {
    /**
     * @notice Returns the address of the Evx Factory contract.
     * @return The factory address used to create and manage pools.
     */
    function factory() external view returns (address);

    /**
     * @notice Returns the address of the WETH9 contract.
     * @return The WETH9 address used for wrapping/unwrapping native ETH.
     */
    function WETH9() external view returns (address);
}
