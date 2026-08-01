// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-core/libraries/FixedPoint96.sol";

/// @title FixedPoint96 Library Test Suite
/// @notice Unit tests for FixedPoint96 constants and fixed-point behaviors
contract FixedPoint96Test is Test {
    /// @notice RESOLUTION constant should equal 96
    function testResolutionConstant() public pure {
        assertEq(FixedPoint96.RESOLUTION, 96, "FixedPoint96.RESOLUTION should be 96");
    }

    /// @notice Q96 constant should equal 2**96
    function testQ96Constant() public pure {
        assertEq(FixedPoint96.Q96, uint256(1) << FixedPoint96.RESOLUTION, "FixedPoint96.Q96 should be 2**RESOLUTION");
    }

    /// @notice Shifting Q96 right by RESOLUTION should yield 1
    function testQ96ShiftRight() public pure {
        assertEq(FixedPoint96.Q96 >> FixedPoint96.RESOLUTION, 1, "Q96 >> RESOLUTION should equal 1");
    }

    /// @notice Multiplying an integer by Q96 and shifting right by RESOLUTION should recover the integer
    function testScalingAndShifting() public pure {
        uint256 x = 123456789;
        uint256 scaled = x * FixedPoint96.Q96;
        // Right shift to revert fixed-point scaling
        assertEq(scaled >> FixedPoint96.RESOLUTION, x, "(x * Q96) >> RESOLUTION should equal x");
    }
}
