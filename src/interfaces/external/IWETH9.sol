// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/**
 * @title IWETH9
 * @notice Interface for Wrapped Ether (WETH9) contract.
 * @dev WETH9 is an ERC20-compliant token that wraps native ETH into an ERC20 form.
 */
interface IWETH9 is IERC20 {
    /**
     * @notice Wraps native ETH into WETH by depositing it into the contract.
     * @dev Mints WETH tokens equal to the amount of ETH sent with the transaction.
     * Emits a {Transfer} event from address(0) to msg.sender.
     */
    function deposit() external payable;

    /**
     * @notice Unwraps WETH into native ETH by burning the specified amount.
     * @dev Burns WETH and sends equivalent ETH to the caller.
     * Emits a {Transfer} event from msg.sender to address(0).
     * @param amount The amount of WETH to unwrap into ETH.
     */
    function withdraw(uint256 amount) external;
}
