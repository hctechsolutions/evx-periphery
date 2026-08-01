// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Permissioned pool actions
 * @notice Contains pool methods restricted to the factory owner for managing protocol fees
 */
interface IEvxPoolOwnerActions {
    /**
     * @notice Sets the denominator of the protocol's share of the fees for each token
     * @dev feeProtocol values represent the inverse of the percentage taken, e.g., a value of 4 means a 25% share
     * @param feeProtocol0 New protocol fee denominator for token0 of the pool
     * @param feeProtocol1 New protocol fee denominator for token1 of the pool
     */
    function setFeeProtocol(uint8 feeProtocol0, uint8 feeProtocol1) external;

    /**
     * @notice Collects the accumulated protocol fees from the pool
     * @dev Only callable by the factory owner; token amounts paid will not exceed requested amounts
     * @param recipient Address to which collected protocol fees should be sent
     * @param amount0Requested Maximum amount of token0 to withdraw, set to 0 to skip token0
     * @param amount1Requested Maximum amount of token1 to withdraw, set to 0 to skip token1
     * @return amount0 The protocol fee collected in token0 and sent to `recipient`
     * @return amount1 The protocol fee collected in token1 and sent to `recipient`
     */
    function collectProtocol(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);
}
