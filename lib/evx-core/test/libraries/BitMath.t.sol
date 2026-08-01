// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-core/libraries/BitMath.sol";

/// @title BitMath Library Test Suite
/// @notice Unit tests for BitMath library covering MSB and LSB logic and error cases
/// @dev Uses an external harness to properly catch internal reverts
contract BitMathHarness {
    /// @notice Wrapper for mostSignificantBit to allow external calls
    function msb(uint256 x) external pure returns (uint8) {
        return BitMath.mostSignificantBit(x);
    }

    /// @notice Wrapper for leastSignificantBit to allow external calls
    function lsb(uint256 x) external pure returns (uint8) {
        return BitMath.leastSignificantBit(x);
    }
}

contract BitMathTest is Test {
    BitMathHarness harness;

    /// @notice Deploy harness before tests
    function setUp() public {
        harness = new BitMathHarness();
    }

    /// @notice Reverts when calling mostSignificantBit with zero
    function testMostSignificantBitZeroReverts() public {
        vm.expectRevert();
        harness.msb(0);
    }

    /// @notice Reverts when calling leastSignificantBit with zero
    function testLeastSignificantBitZeroReverts() public {
        vm.expectRevert();
        harness.lsb(0);
    }

    /// @notice Returns correct index for exact powers of two
    function testMostSignificantBitPowersOfTwo() public pure {
        for (uint8 i = 0; i < 8; i++) {
            uint256 x = uint256(1) << i;
            assertEq(BitMath.mostSignificantBit(x), i, "MSB of power-of-two mismatch");
        }
        assertEq(BitMath.mostSignificantBit(1 << 200), 200, "MSB of 2^200 mismatch");
        uint256 mixed = (uint256(1) << 100) + (uint256(1) << 50);
        assertEq(BitMath.mostSignificantBit(mixed), 100, "MSB of mixed bits mismatch");
        assertEq(BitMath.mostSignificantBit(type(uint256).max), 255, "MSB of max uint256 mismatch");
    }

    /// @notice Returns correct index for non-power-of-two inputs
    function testMostSignificantBitNonPowersOfTwo() public pure {
        assertEq(BitMath.mostSignificantBit(3), 1, "MSB of 3 should be 1");
        assertEq(BitMath.mostSignificantBit(5), 2, "MSB of 5 should be 2");
        assertEq(BitMath.mostSignificantBit(0x123456), 20, "MSB of 0x123456 should be 20");
    }

    /// @notice Returns correct index for least significant bit on basic inputs
    function testLeastSignificantBitBasics() public pure {
        assertEq(BitMath.leastSignificantBit(1), 0, "LSB of 1 should be 0");
        assertEq(BitMath.leastSignificantBit(2), 1, "LSB of 2 should be 1");
        assertEq(BitMath.leastSignificantBit(3), 0, "LSB of 3 should be 0");
        assertEq(BitMath.leastSignificantBit(4), 2, "LSB of 4 should be 2");
    }

    /// @notice Handles mixed and large values for leastSignificantBit
    function testLeastSignificantBitMixedAndLarge() public pure {
        uint256 mixed = (uint256(1) << 100) + (uint256(1) << 50);
        assertEq(BitMath.leastSignificantBit(mixed), 50, "LSB of mixed bits mismatch");
        assertEq(BitMath.leastSignificantBit(1 << 200), 200, "LSB of 2^200 mismatch");
        assertEq(BitMath.leastSignificantBit(type(uint256).max), 0, "LSB of max uint256 mismatch");
    }
}
