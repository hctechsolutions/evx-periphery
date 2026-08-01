// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-core/libraries/SqrtPriceMath.sol";
import "@evx-core/libraries/SwapMath.sol";
import "@evx-core/libraries/UnsafeMath.sol";
import "@evx-core/libraries/FixedPoint96.sol";

/// @notice Harness to call SwapMath.computeSwapStep
contract SwapMathHarness {
    function computeStep(
        uint160 current,
        uint160 target,
        uint128 liquidity,
        int256 amountRemaining,
        uint24 feePips
    ) external pure returns (
        uint160 next,
        uint256 amountIn,
        uint256 amountOut,
        uint256 feeAmount
    ) {
        return SwapMath.computeSwapStep(
            current, target, liquidity, amountRemaining, feePips
        );
    }
}

/// @title SwapMath Library Test Suite
contract SwapMathTest is Test {
    SwapMathHarness harness;
    uint160 constant Q96 = uint160(1) << FixedPoint96.RESOLUTION;

    function setUp() public {
        harness = new SwapMathHarness();
    }

    /// @notice Zero amountRemaining returns same price and zero amounts/fee
    function testComputeStepZeroAmount() public view {
        (uint160 next, uint256 inAmt, uint256 outAmt, uint256 fee) =
            harness.computeStep(Q96, Q96, 1, 0, 3000);
        assertEq(next, Q96, "Price should remain");
        assertEq(inAmt, 0, "AmountIn should be 0");
        assertEq(outAmt, 0, "AmountOut should be 0");
        assertEq(fee, 0, "Fee should be 0");
    }

        /// @notice exactIn, zeroForOne=false (token1 swap in)
    function testComputeStepExactInToken1() public view{
        uint160 current = Q96;
        uint160 target = Q96 << 1; // 2*Q96
        int256 amountRemaining = 100;
        uint24 feePips = 3000;
        (uint160 next, uint256 inAmt, uint256 outAmt, uint256 fee) =
            harness.computeStep(current, target, 1, amountRemaining, feePips);
        // Price should hit target
        assertEq(next, target, "Should reach target price");
        // amountIn = 1
        assertEq(inAmt, 1, "AmountIn mismatch");
        // amountOut = 0
        assertEq(outAmt, 0, "AmountOut mismatch");
        // fee = ceil(1*feePips/(1e6-feePips)) = 1
        assertEq(fee, 1, "Fee mismatch");
    }

        /// @notice exactIn, zeroForOne=true (token0 swap in)
    function testComputeStepExactInToken0() public view {
        uint160 current = Q96 << 1;
        uint160 target = Q96;
        int256 amountRemaining = 100;
        uint24 feePips = 5000;
        (uint160 next, uint256 inAmt, uint256 outAmt, uint256 fee) =
            harness.computeStep(current, target, 1, amountRemaining, feePips);
        assertEq(next, target, "Should reach target price");
        // amountIn computed by getAmount0Delta: should be 1
        assertEq(inAmt, 1, "AmountIn mismatch");
        // amountOut computed by getAmount1Delta: should be 1
        assertEq(outAmt, 1, "AmountOut mismatch");
        // fee = ceil(1*feePips/(1e6-feePips)) => positive
        assertGt(fee, 0, "Fee should be >0");
    }

    /// @notice exactOut, zeroForOne=true (token0 out)
    function testComputeStepExactOutToken0() public view {
        uint160 current = Q96 << 1;
        uint160 target = Q96;
        int256 amountRemaining = -100;
        uint24 feePips = 2500;
        (uint160 next, uint256 inAmt, uint256 outAmt, uint256 fee) =
            harness.computeStep(current, target, 1, amountRemaining, feePips);
        assertEq(next, target, "Should reach target price");
        // amountOut recalc =1
        assertEq(outAmt, 1, "AmountOut mismatch");
        // amountIn recalc =1
        assertEq(inAmt, 1, "AmountIn mismatch");
        // fee = ceil(1*feePips/(1e6-feePips))
        assertGt(fee, 0, "Fee should be >0");
    }

        /// @notice exactOut, zeroForOne=false (token1 out)
    function testComputeStepExactOutToken1() public view {
        uint160 current = Q96;
        uint160 target = Q96 << 1;
        int256 amountRemaining = -100;
        uint24 feePips = 10000;
        (uint160 next, uint256 inAmt, uint256 outAmt, uint256 fee) =
            harness.computeStep(current, target, 1, amountRemaining, feePips);
        assertEq(next, target, "Should reach target price");
        // amountOut computed by getAmount0Delta floor: expected 0
        assertEq(outAmt, 0, "AmountOut mismatch");
        // amountIn computed by getAmount1Delta floor: expected 1
        assertEq(inAmt, 1, "AmountIn mismatch");
        assertGt(fee, 0, "Fee should be >0");
    }
}