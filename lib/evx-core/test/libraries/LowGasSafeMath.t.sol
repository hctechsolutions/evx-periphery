// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-core/libraries/LowGasSafeMath.sol";

/// @notice Harness to expose LowGasSafeMath library functions for testing
contract LowGasSafeMathHarness {
    function add(uint256 x, uint256 y) external pure returns (uint256) {
        return LowGasSafeMath.add(x, y);
    }
    function sub(uint256 x, uint256 y) external pure returns (uint256) {
        return LowGasSafeMath.sub(x, y);
    }
    function mul(uint256 x, uint256 y) external pure returns (uint256) {
        return LowGasSafeMath.mul(x, y);
    }
    function addSigned(int256 x, int256 y) external pure returns (int256) {
        return LowGasSafeMath.add(x, y);
    }
    function subSigned(int256 x, int256 y) external pure returns (int256) {
        return LowGasSafeMath.sub(x, y);
    }
}

/// @title LowGasSafeMath Library Test Suite
/// @notice Unit tests for LowGasSafeMath safe arithmetic operations
contract LowGasSafeMathTest is Test {
    LowGasSafeMathHarness harness;

    function setUp() public {
        harness = new LowGasSafeMathHarness();
    }

    // ---------- Unsigned add tests ----------
    function testAddUnsigned() public view {
        assertEq(harness.add(1, 2), 3, "1 + 2 should be 3");
        assertEq(harness.add(0, 0), 0, "0 + 0 should be 0");
    }
    function testAddUnsignedOverflowReverts() public {
        vm.expectRevert();
        harness.add(type(uint256).max, 1);
    }

    // ---------- Unsigned sub tests ----------
    function testSubUnsigned() public view {
        assertEq(harness.sub(5, 3), 2, "5 - 3 should be 2");
        assertEq(harness.sub(0, 0), 0, "0 - 0 should be 0");
    }
    function testSubUnsignedUnderflowReverts() public {
        vm.expectRevert();
        harness.sub(0, 1);
    }

    // ---------- Unsigned mul tests ----------
    function testMulUnsigned() public view {
        assertEq(harness.mul(3, 4), 12, "3 * 4 should be 12");
        assertEq(harness.mul(0, type(uint256).max), 0, "0 * max should be 0");
    }
    function testMulUnsignedOverflowReverts() public {
        vm.expectRevert();
        harness.mul(type(uint256).max, 2);
    }

    // ---------- Signed add tests ----------
    function testAddSigned() public view {
        assertEq(harness.addSigned(10, -3), 7, "10 + (-3) should be 7");
        assertEq(harness.addSigned(-5, 5), 0, "-5 + 5 should be 0");
    }
    function testAddSignedOverflowReverts() public {
        vm.expectRevert();
        harness.addSigned(type(int256).max, 1);
    }
    function testAddSignedUnderflowReverts() public {
        vm.expectRevert();
        harness.addSigned(type(int256).min, -1);
    }

    // ---------- Signed sub tests ----------
    function testSubSigned() public view {
        assertEq(harness.subSigned(5, 3), 2, "5 - 3 should be 2");
        assertEq(harness.subSigned(-2, -3), 1, "-2 - (-3) should be 1");
    }
    function testSubSignedOverflowReverts() public {
        vm.expectRevert();
        harness.subSigned(type(int256).min, 1);
    }
    function testSubSignedUnderflowReverts() public {
        vm.expectRevert();
        harness.subSigned(type(int256).max, -1);
    }
}
