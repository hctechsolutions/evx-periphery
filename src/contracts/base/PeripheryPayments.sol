// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '@evx-periphery/interfaces/IPeripheryPayments.sol';
import '@evx-periphery/interfaces/external/IWETH9.sol';

import '@evx-periphery/libraries/TransferHelper.sol';

import './PeripheryImmutableState.sol';

/**
 * @title PeripheryPayments
 * @notice Handles ETH and ERC20 payments, WETH wrapping/unwrapping, and refunds for periphery contracts.
 * @dev Assumes WETH9 is correctly set and trusted.
 */
abstract contract PeripheryPayments is IPeripheryPayments, PeripheryImmutableState {
    /**
     * @notice Fallback function to receive ETH only from WETH9 contract.
     * @dev Prevents receiving ETH from arbitrary senders.
     */
    receive() external payable {
        require(msg.sender == WETH9, 'Not WETH9');
    }

    /// @inheritdoc IPeripheryPayments
    function unwrapWETH9(uint256 amountMinimum, address recipient) public payable override {
        uint256 balanceWETH9 = IWETH9(WETH9).balanceOf(address(this));
        require(balanceWETH9 >= amountMinimum, 'Insufficient WETH9');

        if (balanceWETH9 > 0) {
            IWETH9(WETH9).withdraw(balanceWETH9);
            TransferHelper.safeTransferETH(recipient, balanceWETH9);
        }
    }

    /// @inheritdoc IPeripheryPayments
    function sweepToken(
        address token,
        uint256 amountMinimum,
        address recipient
    ) public payable override {
        uint256 balanceToken = IERC20(token).balanceOf(address(this));
        require(balanceToken >= amountMinimum, 'Insufficient token');

        if (balanceToken > 0) {
            TransferHelper.safeTransfer(token, recipient, balanceToken);
        }
    }

    /// @inheritdoc IPeripheryPayments
    function refundETH() external payable override {
        if (address(this).balance > 0) TransferHelper.safeTransferETH(msg.sender, address(this).balance);
    }

    /**
     * @notice Performs a token or ETH transfer depending on conditions.
     * @dev Automatically wraps ETH to WETH9 if needed and uses `TransferHelper` for safe transfers.
     * @param token The token to pay.
     * @param payer The entity that must pay.
     * @param recipient The entity that will receive payment.
     * @param value The amount to pay.
     */
    function pay(
        address token,
        address payer,
        address recipient,
        uint256 value
    ) internal {
        if (token == WETH9 && address(this).balance >= value) {
            IWETH9(WETH9).deposit{value: value}();
            IWETH9(WETH9).transfer(recipient, value);
        } else if (payer == address(this)) {
            // Pay with tokens already in the contract (for the exact input multihop case)
            TransferHelper.safeTransfer(token, recipient, value);
        } else {
            // Pull payment
            TransferHelper.safeTransferFrom(token, payer, recipient, value);
        }
    }
}
