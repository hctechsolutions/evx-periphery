// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-core/libraries/FullMath.sol";

/// @notice Harness to expose FullMath library functions for testing
contract FullMathHarness {
    /// @notice External wrapper for mulDiv
    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) external pure returns (uint256) {
        return FullMath.mulDiv(a, b, denominator);
    }

    /// @notice External wrapper for mulDivRoundingUp
    function mulDivRoundingUp(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) external pure returns (uint256) {
        return FullMath.mulDivRoundingUp(a, b, denominator);
    }
}

/// @title FullMath Library Test Suite
/// @notice Unit tests for FullMath.mulDiv and mulDivRoundingUp covering precision, overflow, and reverts
contract FullMathTest is Test {
    FullMathHarness harness;

    function setUp() public {
        harness = new FullMathHarness();
    }

    /// @notice Floor division for small numbers without overflow
    function testMulDivSimple() public view {
        // 6 * 7 / 2 = 21
        assertEq(harness.mulDiv(6, 7, 2), 21);
        // 0 * x / y == 0
        assertEq(harness.mulDiv(0, 100, 5), 0);
    }

    /// @notice mulDiv should revert when denominator is zero
    function testMulDivDenominatorZeroReverts() public {
        vm.expectRevert();
        harness.mulDiv(1, 1, 0);
    }

    /// @notice Floor division in overflow branch (prod1 > 0)
    function testMulDivOverflowCase() public view {
        uint256 a = uint256(1) << 255;
        uint256 b = 2;
        uint256 denom = 2;
        // a*b = 2**256 => result = 2**255
        uint256 expected = uint256(1) << 255;
        assertEq(harness.mulDiv(a, b, denom), expected);
    }

    /// @notice mulDiv should revert when overflow branch denominator too small
    function testMulDivOverflowReverts() public {
        uint256 a = uint256(1) << 255;
        uint256 b = 2;
        uint256 denom = 1; // denom <= prod1 (1) => revert
        vm.expectRevert();
        harness.mulDiv(a, b, denom);
    }

    /// @notice Exact division should not change in rounding-up
    function testMulDivRoundingUpExact() public view {
        // 5*5/5 = 5 exactly
        assertEq(harness.mulDivRoundingUp(5, 5, 5), 5);
    }

    /// @notice Rounding-up should increment when remainder exists
    function testMulDivRoundingUpRound() public view {
        // 3*3/4 = 2.25 => floor=2, roundingUp=3
        assertEq(harness.mulDivRoundingUp(3, 3, 4), 3);
    }

    /// @notice mulDivRoundingUp should revert when denominator is zero
    function testMulDivRoundingUpDenominatorZeroReverts() public {
        vm.expectRevert();
        harness.mulDivRoundingUp(1, 1, 0);
    }

    /// @notice mulDiv should revert for maximum values with overflow branch
    function testMulDivMaxValuesReverts() public {
        vm.expectRevert();
        harness.mulDiv(type(uint256).max, type(uint256).max, type(uint256).max);
    }
}
