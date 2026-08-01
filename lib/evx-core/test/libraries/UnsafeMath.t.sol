// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-core/libraries/UnsafeMath.sol";

/// @notice Harness to expose UnsafeMath.divRoundingUp
contract UnsafeMathHarness {
    function divUp(uint256 x, uint256 y) external pure returns (uint256) {
        return UnsafeMath.divRoundingUp(x, y);
    }
}

/// @title UnsafeMath Library Test Suite
/// @notice Unit tests for divRoundingUp without safety checks
contract UnsafeMathTest is Test {
    UnsafeMathHarness harness;

    function setUp() public {
        harness = new UnsafeMathHarness();
    }

    /// @notice Exact division yields exact result
    function testDivExact() public view {
        assertEq(harness.divUp(10, 2), 5, "10/2 should be 5");
        assertEq(harness.divUp(0, 5), 0, "0/5 should be 0");
    }

    /// @notice Division with remainder rounds up
    function testDivRoundingUp() public view {
        assertEq(harness.divUp(11, 2), 6, "11/2 should round up to 6");
        assertEq(harness.divUp(1, 1), 1, "1/1 should be 1");
    }

    /// @notice Large numbers
    function testDivLargeNumbers() public view {
        uint256 max = type(uint256).max;
        assertEq(harness.divUp(max, 1), max, "max/1 should be max");
        assertEq(harness.divUp(max, max), 1, "max/max should be 1");
    }

        /// @notice Division by zero yields zero (unchecked behavior)
    function testDivByZeroReturnsZero() public view {
        assertEq(harness.divUp(1, 0), 0, "1/0 should return 0");
    }
}
