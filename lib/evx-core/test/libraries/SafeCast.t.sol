// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-core/libraries/SafeCast.sol";

/// @notice Harness to expose SafeCast library functions
contract SafeCastHarness {
    function toUint160(uint256 y) external pure returns (uint160) {
        return SafeCast.toUint160(y);
    }

    function toInt128(int256 y) external pure returns (int128) {
        return SafeCast.toInt128(y);
    }

    function toInt256(uint256 y) external pure returns (int256) {
        return SafeCast.toInt256(y);
    }

    function toInt56(int256 y) external pure returns (int56) {
        return SafeCast.toInt56(y);
    }
}

/// @title SafeCast Library Test Suite
/// @notice Unit tests for SafeCast safe downcasting functions
contract SafeCastTest is Test {
    SafeCastHarness harness;

    function setUp() public {
        harness = new SafeCastHarness();
    }

    /// @notice toUint160 should cast values <= max uint160
    function testToUint160() public view {
        uint256 max160 = type(uint160).max;
        assertEq(harness.toUint160(max160), uint160(max160));
        // zero
        assertEq(harness.toUint160(0), uint160(0));
    }

    /// @notice toUint160 should revert when value > max uint160
    function testToUint160OverflowReverts() public {
        uint256 overflowValue = uint256(type(uint160).max) + 1;
        vm.expectRevert();
        harness.toUint160(overflowValue);
    }

    /// @notice toInt128 should cast values within int128 range
    function testToInt128() public view {
        int256 max128 = int256(type(int128).max);
        int256 min128 = int256(type(int128).min);
        assertEq(harness.toInt128(max128), int128(max128));
        assertEq(harness.toInt128(min128), int128(min128));
        assertEq(harness.toInt128(0), int128(0));
    }

    /// @notice toInt128 should revert when value > max int128 or < min int128
    function testToInt128OverflowReverts() public {
        int256 aboveMax = int256(type(int128).max) + 1;
        vm.expectRevert();
        harness.toInt128(aboveMax);
        int256 belowMin = int256(type(int128).min) - 1;
        vm.expectRevert();
        harness.toInt128(belowMin);
    }

    /// @notice toInt256 should cast values < 2^255
    function testToInt256() public view {
        uint256 maxSigned = uint256(type(int256).max);
        assertEq(harness.toInt256(maxSigned), int256(maxSigned));
        assertEq(harness.toInt256(0), int256(0));
    }

    /// @notice toInt256 should revert when value >= 2^255
    function testToInt256OverflowReverts() public {
        uint256 threshold = uint256(type(int256).max) + 1;
        vm.expectRevert();
        harness.toInt256(threshold);
    }

    /// @notice toInt56 should cast values within int56 range
    function testToInt56() public view {
        int256 max56 = int256(type(int56).max);
        int256 min56 = int256(type(int56).min);
        assertEq(harness.toInt56(max56), int56(max56));
        assertEq(harness.toInt56(min56), int56(min56));
        assertEq(harness.toInt56(0), int56(0));
    }

    /// @notice toInt56 should revert with message on overflow or underflow
    function testToInt56OverflowReverts() public {
        int256 above = int256(type(int56).max) + 1;
        vm.expectRevert(bytes("SafeCast: int56 overflow"));
        harness.toInt56(above);
        int256 below = int256(type(int56).min) - 1;
        vm.expectRevert(bytes("SafeCast: int56 overflow"));
        harness.toInt56(below);
    }
}
