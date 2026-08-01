// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SafeCast
 * @notice Library for safely casting between integer types with overflow and underflow checks.
 * @dev Reverts the transaction if the cast would overflow or underflow.
 */
library SafeCast {
    /**
     * @notice Safely casts a uint256 to uint160.
     * @dev Reverts if `y` is greater than the maximum value of uint160.
     * @param y The unsigned integer to be downcasted.
     * @return z The downcasted value as a uint160.
     */
    function toUint160(uint256 y) internal pure returns (uint160 z) {
        require((z = uint160(y)) == y);
    }

    /**
     * @notice Safely casts an int256 to int128.
     * @dev Reverts if `y` is outside the range of int128.
     * @param y The signed integer to be downcasted.
     * @return z The downcasted value as an int128.
     */
    function toInt128(int256 y) internal pure returns (int128 z) {
        require((z = int128(y)) == y);
    }

    /**
     * @notice Safely casts a uint256 to int256.
     * @dev Reverts if `y` is greater than or equal to 2**255.
     * @param y The unsigned integer to cast.
     * @return z The casted value as an int256.
     */
    function toInt256(uint256 y) internal pure returns (int256 z) {
        require(y < 2**255);
        z = int256(y);
    }

    /**
     * @notice Safely casts an int256 to int56.
     * @dev Reverts if `y` is outside the bounds of int56.
     * @param y The signed integer to be downcasted.
     * @return z The downcasted value as an int56.
     */
    function toInt56(int256 y) internal pure returns (int56 z) {
        int256 min = type(int56).min;
        int256 max = type(int56).max;
        require(y >= min && y <= max, "SafeCast: int56 overflow");
        z = int56(y);
    }
}
