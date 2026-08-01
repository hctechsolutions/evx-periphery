// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title FixedPoint128
 * @notice Library for working with Q128.128 binary fixed-point numbers.
 * @dev Commonly used for high-precision arithmetic involving large scaling factors.
 *      See: https://en.wikipedia.org/wiki/Q_(number_format)
 */
library FixedPoint128 {
    /// @notice The constant 2**128, used to scale integers into Q128.128 fixed-point format.
    uint256 internal constant Q128 = 0x100000000000000000000000000000000;
}
