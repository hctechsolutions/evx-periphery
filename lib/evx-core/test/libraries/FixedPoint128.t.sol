// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-core/libraries/FixedPoint128.sol";

/// @title FixedPoint128 Library Test Suite
/// @notice Unit tests for FixedPoint128 constant and fixed-point behaviors
contract FixedPoint128Test is Test {
    /// @notice Q128 constant should equal 2**128
    function testQ128Constant() public pure {
        assertEq(FixedPoint128.Q128, uint256(1) << 128, "FixedPoint128.Q128 should equal 2**128");
    }

    /// @notice Shifting Q128 right by 128 should yield 1
    function testQ128ShiftRight() public pure {
        assertEq(FixedPoint128.Q128 >> 128, 1, "Q128 >> 128 should equal 1");
    }

    /// @notice Multiplying an integer by Q128 and shifting right by 128 should recover the integer
    function testScalingAndShifting() public pure {
        uint256 x = 0x123456789ABCDEF123456789ABCDEF;
        uint256 scaled = x * FixedPoint128.Q128;
        assertEq(scaled >> 128, x, "(x * Q128) >> 128 should equal x");
    }
}
