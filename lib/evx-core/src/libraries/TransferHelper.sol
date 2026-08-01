// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title TransferHelper
 * @notice Provides safe transfer methods for ERC20 tokens that may not return a boolean.
 * @dev This library ensures compatibility with non-standard ERC20 implementations by handling missing or false return values.
 */
library TransferHelper {
    /**
     * @notice Safely transfers `value` amount of `token` from the caller to `to`.
     * @dev Reverts with 'TF' if the token transfer fails or returns false.
     *      Uses low-level `call` to handle tokens that do not return a boolean value.
     * @param token The address of the ERC20 token contract.
     * @param to The recipient address that will receive the tokens.
     * @param value The amount of tokens to transfer.
     */
    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TF');
    }
}
