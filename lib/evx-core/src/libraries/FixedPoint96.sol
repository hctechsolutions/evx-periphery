// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title FixedPoint96
 * @notice Library for working with Q64.96 binary fixed-point numbers.
 * @dev Commonly used in price and liquidity calculations involving square roots (e.g., in SqrtPriceMath).
 *      See: https://en.wikipedia.org/wiki/Q_(number_format)
 */
library FixedPoint96 {
    /// @notice The number of fractional bits used in the fixed-point format (Q96).
    uint8 internal constant RESOLUTION = 96;

    /// @notice The constant 2**96, used to scale integers into Q64.96 fixed-point format.
    uint256 internal constant Q96 = 0x1000000000000000000000000;
}
