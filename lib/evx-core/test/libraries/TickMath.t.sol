// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-core/libraries/FixedPoint96.sol";
import "@evx-core/libraries/TickMath.sol";

/// @notice Harness to expose TickMath library functions
contract TickMathHarness {
    function getSqrtRatio(int24 tick) external pure returns (uint160) {
        return TickMath.getSqrtRatioAtTick(tick);
    }
    function getTickAtSqrt(uint160 sqrtPriceX96) external pure returns (int24) {
        return TickMath.getTickAtSqrtRatio(sqrtPriceX96);
    }
}

/// @title TickMath Library Test Suite
/// @notice Unit tests for getSqrtRatioAtTick and getTickAtSqrtRatio
contract TickMathTest is Test {
    TickMathHarness harness;

    function setUp() public {
        harness = new TickMathHarness();
    }

    /// @notice getSqrtRatioAtTick of zero tick should equal Q96
    function testGetSqrtRatioAtTickZero() public view {
        uint160 sqrt0 = harness.getSqrtRatio(0);
        assertEq(sqrt0, uint160(1) << FixedPoint96.RESOLUTION, "sqrtPrice at tick 0 should be Q96");
    }

    /// @notice getSqrtRatioAtTick at MIN_TICK and MAX_TICK should return boundary ratios
    function testGetSqrtRatioAtTickBounds() public view {
        uint160 minRatio = harness.getSqrtRatio(int24(TickMath.MIN_TICK));
        assertEq(minRatio, TickMath.MIN_SQRT_RATIO, "MIN_TICK sqrt ratio mismatch");
        uint160 maxRatio = harness.getSqrtRatio(int24(TickMath.MAX_TICK));
        assertEq(maxRatio, TickMath.MAX_SQRT_RATIO, "MAX_TICK sqrt ratio mismatch");
    }

    /// @notice getSqrtRatioAtTick should revert for ticks outside allowable range
    function testGetSqrtRatioAtTickReverts() public {
        vm.expectRevert(bytes("T"));
        harness.getSqrtRatio(int24(TickMath.MIN_TICK) - 1);
        vm.expectRevert(bytes("T"));
        harness.getSqrtRatio(int24(TickMath.MAX_TICK) + 1);
    }

    /// @notice getTickAtSqrtRatio on MIN_SQRT_RATIO should return MIN_TICK
    function testGetTickAtSqrtRatioAtMin() public view {
        int24 tick = harness.getTickAtSqrt(TickMath.MIN_SQRT_RATIO);
        assertEq(tick, TickMath.MIN_TICK, "tick from MIN_SQRT_RATIO mismatch");
    }

    /// @notice getTickAtSqrtRatio should revert for out-of-bounds sqrt prices
    function testGetTickAtSqrtRatioReverts() public {
        vm.expectRevert(bytes("R"));
        harness.getTickAtSqrt(uint160(TickMath.MIN_SQRT_RATIO) - 1);
        vm.expectRevert(bytes("R"));
        harness.getTickAtSqrt(TickMath.MAX_SQRT_RATIO);
    }

    /// @notice Round-trip: getTickAtSqrtRatio(getSqrtRatioAtTick(t)) == t for various ticks
        /// @notice Round-trip: getTickAtSqrtRatio(getSqrtRatioAtTick(t)) == t for various ticks (excluding MAX_TICK)
    function testRoundTripTicks() public view {
        int24[] memory samples = new int24[](4);
        samples[0] = int24(TickMath.MIN_TICK);
        samples[1] = -100000;
        samples[2] = 0;
        samples[3] = 100000;
        for (uint256 i = 0; i < samples.length; i++) {
            int24 t = samples[i];
            uint160 sqrt = harness.getSqrtRatio(t);
            int24 recovered = harness.getTickAtSqrt(sqrt);
            assertEq(recovered, t, "round-trip tick mismatch");
        }
    }
}
