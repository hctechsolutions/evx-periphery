// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title UnsafeMath
 * @notice Provides mathematical functions without input or overflow checks.
 * @dev This library should be used with caution. Ensure that inputs are validated externally.
 */
library UnsafeMath {
    /**
     * @notice Computes the ceiling of the division between two numbers.
     * @dev This function does not check for division by zero. Caller must ensure `y != 0`.
     *      Result is equivalent to `ceil(x / y)`, meaning it rounds up the result if there is any remainder.
     * @param x The dividend.
     * @param y The divisor.
     * @return z The result of `ceil(x / y)`.
     */
    function divRoundingUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            z := add(div(x, y), gt(mod(x, y), 0))
        }
    }
}
