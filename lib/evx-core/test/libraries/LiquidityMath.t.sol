// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-core/libraries/LiquidityMath.sol";

/// @notice Harness to expose LiquidityMath library for testing
contract LiquidityMathHarness {
    /// @notice External wrapper for addDelta
    function addDelta(uint128 x, int128 y) external pure returns (uint128) {
        return LiquidityMath.addDelta(x, y);
    }
}

/// @title LiquidityMath Library Test Suite
/// @notice Unit tests for LiquidityMath.addDelta covering increases, decreases, and error conditions
contract LiquidityMathTest is Test {
    LiquidityMathHarness harness;

    function setUp() public {
        harness = new LiquidityMathHarness();
    }

    /// @notice Adding zero delta should return the same liquidity
    function testAddDeltaZero() public view {
        uint128 x = 12345;
        assertEq(harness.addDelta(x, 0), x, "addDelta(x,0) should equal x");
    }

    /// @notice Increasing liquidity by a positive delta
    function testAddDeltaIncrease() public view {
        uint128 x = 100;
        int128 y = 50;
        assertEq(harness.addDelta(x, y), 150, "addDelta(100,+50) should be 150");
    }

    /// @notice Decreasing liquidity by a negative delta
    function testAddDeltaDecrease() public view {
        uint128 x = 200;
        int128 y = -75;
        assertEq(harness.addDelta(x, y), 125, "addDelta(200,-75) should be 125");
    }

    /// @notice Decrease by full amount should yield zero
    function testAddDeltaDecreaseToZero() public view {
        uint128 x = 500;
        int128 y = -int128(uint128(x));
        assertEq(harness.addDelta(x, y), 0, "addDelta(x, -x) should be 0");
    }

    /// @notice Increasing liquidity within uint128 max should succeed
    function testAddDeltaMaxIncrease() public view {
        uint128 x = type(uint128).max - 1;
        int128 y = 1;
        assertEq(harness.addDelta(x, y), type(uint128).max, "addDelta(max-1,+1) should be max");
    }

    /// @notice Adding delta that causes overflow should revert with 'LA'
    function testAddDeltaOverflowReverts() public {
        uint128 x = type(uint128).max;
        int128 y = 1;
        vm.expectRevert(bytes("LA"));
        harness.addDelta(x, y);
    }

    /// @notice Subtracting delta greater than x should revert with 'LS'
    function testAddDeltaUnderflowReverts() public {
        uint128 x = 10;
        int128 y = -20;
        vm.expectRevert(bytes("LS"));
        harness.addDelta(x, y);
    }
}
