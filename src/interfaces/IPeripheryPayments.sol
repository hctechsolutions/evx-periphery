// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPeripheryPayments
 * @notice Interface for handling ETH/WETH interactions and token transfers in periphery contracts.
 * @dev Facilitates safe ETH refunds, WETH unwraps, and token sweeps for contract balances.
 */
interface IPeripheryPayments {
    /**
     * @notice Unwraps the contract's WETH9 balance and sends it to the recipient as ETH.
     * @dev Ensures at least `amountMinimum` WETH9 is available to prevent malicious siphoning.
     * @param amountMinimum The minimum amount of WETH9 required to perform the unwrap.
     * @param recipient The address that will receive the unwrapped ETH.
     */
    function unwrapWETH9(uint256 amountMinimum, address recipient) external payable;

    /**
     * @notice Refunds any excess ETH held by the contract back to the original sender.
     * @dev Useful when excess ETH is left after operations like swaps or minting that use ETH as input.
     */
    function refundETH() external payable;

    /**
     * @notice Transfers the full balance of a given token held by this contract to the recipient.
     * @dev Ensures that the balance is at least `amountMinimum` to protect users from dust attacks.
     * @param token The address of the ERC20 token to transfer.
     * @param amountMinimum The minimum amount required to allow the transfer.
     * @param recipient The address that will receive the token.
     */
    function sweepToken(
        address token,
        uint256 amountMinimum,
        address recipient
    ) external payable;
}
