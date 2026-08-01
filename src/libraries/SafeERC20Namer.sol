// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@evx-periphery/libraries/AddressStringUtil.sol';

/**
 * @title SafeERC20Namer
 * @notice Safely extracts or infers ERC20 token names and symbols, handling inconsistent implementations.
 * @dev Fallback heuristics generate names/symbols based on the token's address if not implemented.
 */
library SafeERC20Namer {
    /**
     * @notice Converts a bytes32 string into a normal string by trimming null bytes.
     * @param x The bytes32 value to convert.
     * @return The resulting trimmed string.
     */
    function bytes32ToString(bytes32 x) private pure returns (string memory) {
        bytes memory bytesString = new bytes(32);
        uint256 charCount = 0;
        for (uint256 j = 0; j < 32; j++) {
            bytes1 char = x[j];
            if (char != 0) {
                bytesString[charCount] = char;
                charCount++;
            }
        }
        bytes memory bytesStringTrimmed = new bytes(charCount);
        for (uint256 j = 0; j < charCount; j++) {
            bytesStringTrimmed[j] = bytesString[j];
        }
        return string(bytesStringTrimmed);
    }

    /**
     * @notice Decodes a string from ABI-encoded bytes return data.
     * @dev Assumes the string is in position 2 of the return and has a 32-byte length prefix.
     * @param b The raw bytes to decode.
     * @return The parsed string.
     */
    function parseStringData(bytes memory b) private pure returns (string memory) {
        uint256 charCount = 0;
        
        // first parse the charCount out of the data
        for (uint256 i = 32; i < 64; i++) {
            charCount <<= 8;
            charCount += uint8(b[i]);
        }

        bytes memory bytesStringTrimmed = new bytes(charCount);
        for (uint256 i = 0; i < charCount; i++) {
            bytesStringTrimmed[i] = b[i + 64];
        }

        return string(bytesStringTrimmed);
    }

    /**
     * @notice Generates a fallback name using the full uppercase hex of the address.
     * @param token The token address.
     * @return The generated name string.
     */
    function addressToName(address token) private pure returns (string memory) {
        return AddressStringUtil.toAsciiString(token, 40);
    }

    /**
     * @notice Generates a fallback symbol using the first 6 uppercase hex characters of the address.
     * @param token The token address.
     * @return The generated symbol string.
     */
    function addressToSymbol(address token) private pure returns (string memory) {
        return AddressStringUtil.toAsciiString(token, 6);
    }

    /**
     * @notice Calls a token contract's view method and parses its string or bytes32 return.
     * @param token The token address.
     * @param selector The bytes4 selector of the function (e.g., symbol() or name()).
     * @return The parsed string result or empty string if failed or not implemented.
     */
    function callAndParseStringReturn(address token, bytes4 selector) private view returns (string memory) {
        (bool success, bytes memory data) = token.staticcall(abi.encodeWithSelector(selector));
        
        // If not implemented, or returns empty data, return empty string
        if (!success || data.length == 0) {
            return '';
        }
        
        // Bytes32 data always has length 32
        if (data.length == 32) {
            bytes32 decoded = abi.decode(data, (bytes32));
            return bytes32ToString(decoded);
        } else if (data.length > 64) {
            return abi.decode(data, (string));
        }
        return '';
    }

    /**
     * @notice Retrieves the symbol of an ERC20 token, falling back to address-derived string if unavailable.
     * @param token The token address.
     * @return The symbol as a string.
     */
    function tokenSymbol(address token) internal view returns (string memory) {
        string memory symbol = callAndParseStringReturn(token, 0x95d89b41); // symbol()
        if (bytes(symbol).length == 0) {
            // Fallback to 6 uppercase hex of address
            return addressToSymbol(token);
        }
        return symbol;
    }

    /**
     * @notice Retrieves the name of an ERC20 token, falling back to address-derived string if unavailable.
     * @param token The token address.
     * @return The name as a string.
     */
    function tokenName(address token) internal view returns (string memory) {
        string memory name = callAndParseStringReturn(token, 0x06fdde03);
        if (bytes(name).length == 0) {
            // Fallback to full hex of address
            return addressToName(token);
        }
        return name;
    }
}
