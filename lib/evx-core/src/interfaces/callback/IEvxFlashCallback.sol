// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IEvxFlashCallback
 * @notice Interface for contracts that use flash loans via IEvxPoolActions#flash.
 * @dev Contracts executing a flash loan must implement this interface to handle the callback and repay the loan.
 */
interface IEvxFlashCallback {
    /**
     * @notice Callback invoked by an EvxPool after executing a flash loan.
     * @dev The recipient must repay the borrowed amount plus the fees for both token0 and token1 within this call.
     *      The caller must be validated to ensure it is an EvxPool deployed by the canonical EvxFactory.
     * @param fee0 Amount of token0 that must be repaid as a fee.
     * @param fee1 Amount of token1 that must be repaid as a fee.
     * @param data Arbitrary data passed through from the original flash call.
     */
    function evxFlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external;
}
