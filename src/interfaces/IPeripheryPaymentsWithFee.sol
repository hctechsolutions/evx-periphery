// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import './IPeripheryPayments.sol';

/**
 * @title IPeripheryPaymentsWithFee
 * @notice Extension of `IPeripheryPayments` that supports fee splitting during unwraps and token sweeps.
 * @dev Enables automatic distribution of a portion of ETH or token value to a designated fee recipient.
 */
interface IPeripheryPaymentsWithFee is IPeripheryPayments {
    /**
     * @notice Unwraps the contract's WETH9 balance and sends ETH to `recipient`, allocating a portion as a fee.
     * @dev The fee is expressed in basis points (bips), where 10000 = 100%.
     * Reverts if balance is below `amountMinimum` or fee exceeds total.
     *
     * @param amountMinimum Minimum amount of WETH9 required to unwrap.
     * @param recipient The address receiving the ETH after unwrapping.
     * @param feeBips Fee in basis points (e.g., 100 = 1%).
     * @param feeRecipient Address receiving the ETH fee.
     */
    function unwrapWETH9WithFee(
        uint256 amountMinimum,
        address recipient,
        uint256 feeBips,
        address feeRecipient
    ) external payable;

    /**
     * @notice Transfers full token balance to `recipient`, sending a portion as a fee to `feeRecipient`.
     * @dev The fee is expressed in basis points. Reverts if token balance is below `amountMinimum`.
     *
     * @param token Address of the ERC20 token to transfer.
     * @param amountMinimum Minimum balance required to allow the sweep.
     * @param recipient The address receiving the token minus the fee.
     * @param feeBips Fee in basis points (1% = 100).
     * @param feeRecipient The address receiving the fee portion.
     */
    function sweepTokenWithFee(
        address token,
        uint256 amountMinimum,
        address recipient,
        uint256 feeBips,
        address feeRecipient
    ) external payable;
}
