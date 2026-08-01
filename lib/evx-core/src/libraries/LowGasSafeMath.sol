// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LowGasSafeMath
 * @notice Optimized math library for safe arithmetic with minimal gas overhead.
 * @dev Provides overflow- and underflow-safe arithmetic operations for both signed and unsigned integers.
 */
library LowGasSafeMath {
    /**
     * @notice Adds two unsigned integers and reverts on overflow.
     * @param x The augend.
     * @param y The addend.
     * @return z The sum of x and y.
     */
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x);
    }

    /**
     * @notice Subtracts one unsigned integer from another and reverts on underflow.
     * @param x The minuend.
     * @param y The subtrahend.
     * @return z The difference of x and y.
     */
    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }

    /**
     * @notice Multiplies two unsigned integers and reverts on overflow.
     * @param x The multiplicand.
     * @param y The multiplier.
     * @return z The product of x and y.
     */
    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(x == 0 || (z = x * y) / x == y);
    }

    /**
     * @notice Adds two signed integers and reverts on overflow or underflow.
     * @param x The augend.
     * @param y The addend.
     * @return z The sum of x and y.
     */
    function add(int256 x, int256 y) internal pure returns (int256 z) {
        require((z = x + y) >= x == (y >= 0));
    }

    /**
     * @notice Subtracts one signed integer from another and reverts on overflow or underflow.
     * @param x The minuend.
     * @param y The subtrahend.
     * @return z The difference of x and y.
     */
    function sub(int256 x, int256 y) internal pure returns (int256 z) {
        require((z = x - y) <= x == (y >= 0));
    }
}
