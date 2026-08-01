// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/**
 * @notice Utility functions for safely transferring ERC20 tokens and ETH.
 * @dev Supports non-standard ERC20s by using low-level calls and return value checks.
 */
library TransferHelper {
    /**
     * @notice Transfers tokens from the targeted address to the given destination.
     * @dev Reverts with 'STF' if the transfer fails. Uses ERC20 `transferFrom`.
     * @param token The address of the token to be transferred.
     * @param from The source address from which the tokens are pulled.
     * @param to The destination address to receive the tokens.
     * @param value The amount of tokens to transfer.
     */
    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // 0x23b872dd = IERC20.transferFrom.selector
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'STF');
    }

    /**
     * @notice Transfers tokens from msg.sender to the recipient.
     * @dev Reverts with 'ST' if the transfer fails. Uses ERC20 `transfer`.
     * @param token The address of the token to be transferred.
     * @param to The destination address to receive the tokens.
     * @param value The amount of tokens to transfer.
     */
    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // 0xa9059cbb = IERC20.transfer.selector
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'ST');
    }

    /**
     * @notice Approves a spender to spend a specific amount of tokens on behalf of the caller.
     * @dev Reverts with 'SA' if the approval fails. Uses ERC20 `approve`.
     * @param token The address of the token to be approved.
     * @param to The address that will be allowed to spend the tokens.
     * @param value The amount of tokens to approve.
     */
    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        // 0x095ea7b3 = IERC20.approve.selector
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.approve.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'SA');
    }

    /**
     * @notice Transfers ETH to the given recipient.
     * @dev Reverts with 'STE' if the transfer fails.
     * @param to The destination address to receive the ETH.
     * @param value The amount of ETH to transfer (in wei).
     */
    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'STE');
    }
}
