// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title HexStrings
 * @notice Utility library for converting uint256 values to hexadecimal string representations.
 * @dev Inspired by OpenZeppelin's Strings library (MIT License).
 */
library HexStrings {
    bytes16 internal constant ALPHABET = '0123456789abcdef';

    /**
     * @notice Converts a uint256 value to a hexadecimal string with `0x` prefix and fixed length.
     * @dev Reverts if the length is insufficient to represent the value.
     * @param value The number to convert.
     * @param length The fixed number of bytes to represent (resulting string will have length `2 * length + 2`).
     * @return The hexadecimal string representation with `0x` prefix.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = '0';
        buffer[1] = 'x';
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = ALPHABET[value & 0xf];
            value >>= 4;
        }
        require(value == 0, 'Strings: hex length insufficient');
        return string(buffer);
    }

    /**
     * @notice Converts a uint256 value to a hexadecimal string without any prefix and with fixed length.
     * @dev No `0x` prefix is added. Output length is `2 * length` characters.
     * @param value The number to convert.
     * @param length The number of bytes to represent.
     * @return The hexadecimal string representation without prefix.
     */
    function toHexStringNoPrefix(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length);
        for (uint256 i = buffer.length; i > 0; i--) {
            buffer[i - 1] = ALPHABET[value & 0xf];
            value >>= 4;
        }
        return string(buffer);
    }
}
