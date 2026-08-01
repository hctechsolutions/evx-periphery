// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title AddressStringUtil
 * @notice Utility library for converting addresses to fixed-length uppercase hexadecimal strings.
 */
library AddressStringUtil {
    /**
     * @notice Converts an address to a hexadecimal string of a given length.
     * @dev The length must be even, nonzero, and less than or equal to 40 (i.e., up to 20 bytes).
     * @param addr The address to convert.
     * @param len The number of hex characters to extract (must be even and <= 40).
     * @return The uppercase hex string representation of the address.
     */
    function toAsciiString(address addr, uint256 len) internal pure returns (string memory) {
        require(len % 2 == 0 && len > 0 && len <= 40, 'AddressStringUtil: INVALID_LEN');

        bytes memory s = new bytes(len);
        uint256 addrNum = uint256(uint160(addr));
        for (uint256 i = 0; i < len / 2; i++) {
            // Extract the i-th byte from the right
            uint8 b = uint8(addrNum >> (8 * (19 - i)));
            uint8 hi = b >> 4;
            uint8 lo = b & 0x0f;
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }
        return string(s);
    }

    /**
     * @notice Converts a 4-bit value into its ASCII hex character.
     * @dev Uses uppercase characters ('0'-'9', 'A'-'F').
     * @param b The value to convert (0-15).
     * @return c The corresponding ASCII hex character.
     */
    function char(uint8 b) private pure returns (bytes1 c) {
        if (b < 10) {
            return bytes1(b + 0x30); // '0' - '9'
        } else {
            return bytes1(b + 0x37); // 'A' - 'F'
        }
    }
} 
