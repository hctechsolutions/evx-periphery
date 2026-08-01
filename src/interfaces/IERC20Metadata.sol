// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/**
 * @title IERC20Metadata
 * @notice ERC20 interface extension that includes token metadata: name, symbol, and decimals.
 * @dev Optional interface, often implemented by ERC20 tokens for display purposes.
 */
interface IERC20Metadata is IERC20 {
    /**
     * @notice Returns the name of the token.
     * @return The full name of the token (e.g., "Dai Stablecoin").
     */
    function name() external view returns (string memory);

    /**
     * @notice Returns the symbol of the token.
     * @return The short symbol of the token (e.g., "DAI").
     */
    function symbol() external view returns (string memory);

    /**
     * @notice Returns the number of decimals used for user representations.
     * @dev This value is used to format balances for display (e.g., 18 means 1e18 units = 1 token).
     * @return The number of decimal places the token uses.
     */
    function decimals() external view returns (uint8);
}
