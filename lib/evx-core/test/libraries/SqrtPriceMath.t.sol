// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-core/libraries/SqrtPriceMath.sol";
import "@evx-core/libraries/UnsafeMath.sol";

/// @notice Harness to expose SqrtPriceMath library for testing
contract SqrtPriceMathHarness {
    function getNextSqrtPriceFromAmount0RoundingUp(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 amount,
        bool add
    ) external pure returns (uint160) {
        return SqrtPriceMath.getNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amount, add);
    }

    function getNextSqrtPriceFromAmount1RoundingDown(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 amount,
        bool add
    ) external pure returns (uint160) {
        return SqrtPriceMath.getNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amount, add);
    }

    function getNextSqrtPriceFromInput(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) external pure returns (uint160) {
        return SqrtPriceMath.getNextSqrtPriceFromInput(sqrtPX96, liquidity, amountIn, zeroForOne);
    }

    function getNextSqrtPriceFromOutput(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 amountOut,
        bool zeroForOne
    ) external pure returns (uint160) {
        return SqrtPriceMath.getNextSqrtPriceFromOutput(sqrtPX96, liquidity, amountOut, zeroForOne);
    }

    function getAmount0DeltaUnsigned(
        uint160 a,
        uint160 b,
        uint128 liquidity,
        bool roundUp
    ) external pure returns (uint256) {
        return SqrtPriceMath.getAmount0Delta(a, b, liquidity, roundUp);
    }

    function getAmount1DeltaUnsigned(
        uint160 a,
        uint160 b,
        uint128 liquidity,
        bool roundUp
    ) external pure returns (uint256) {
        return SqrtPriceMath.getAmount1Delta(a, b, liquidity, roundUp);
    }

    function getAmount0DeltaSigned(
        uint160 a,
        uint160 b,
        int128 liquidity
    ) external pure returns (int256) {
        return SqrtPriceMath.getAmount0Delta(a, b, liquidity);
    }

    function getAmount1DeltaSigned(
        uint160 a,
        uint160 b,
        int128 liquidity
    ) external pure returns (int256) {
        return SqrtPriceMath.getAmount1Delta(a, b, liquidity);
    }
}

/// @title SqrtPriceMath Library Test Suite
contract SqrtPriceMathTest is Test {
    SqrtPriceMathHarness harness;
    uint160 constant Q96 = uint160(1) << FixedPoint96.RESOLUTION;

    function setUp() public {
        harness = new SqrtPriceMathHarness();
    }

    /// @notice amount0 zero should return same price
    function testGetNextSqrtPriceFromAmount0Zero() public view {
        assertEq(
            harness.getNextSqrtPriceFromAmount0RoundingUp(Q96, 1, 0, true),
            Q96
        );
    }

    /// @notice amount0 addition simple case
    function testGetNextSqrtPriceFromAmount0Add() public view {
        // sqrt price = 1 => Q96, liquidity=1, amount=1
        uint160 next = harness.getNextSqrtPriceFromAmount0RoundingUp(Q96, 1, 1, true);
        // expect Q96/2
        assertEq(next, Q96 >> 1);
    }

    /// @notice amount0 removal simple case
    function testGetNextSqrtPriceFromAmount0Remove() public view {
        // liquidity=2, amount=1
        uint160 next = harness.getNextSqrtPriceFromAmount0RoundingUp(Q96, 2, 1, false);
        // expect Q96*2 (2**97)
        assertEq(next, Q96 << 1);
    }

    /// @notice amount1 addition simple case
    function testGetNextSqrtPriceFromAmount1Add() public view {
        uint160 next = harness.getNextSqrtPriceFromAmount1RoundingDown(Q96, 1, 1, true);
        // expect Q96 + Q96 = 2*Q96
        assertEq(next, Q96 << 1);
    }

    /// @notice amount1 removal simple case
    function testGetNextSqrtPriceFromAmount1Remove() public view {
        uint160 next = harness.getNextSqrtPriceFromAmount1RoundingDown(Q96, 2, 1, false);
        // expect Q96 - (Q96/2)
        assertEq(next, Q96 >> 1);
    }

    /// @notice getNextSqrtPriceFromInput with zero amount returns same price
    function testGetNextSqrtPriceFromInputZero() public view {
        assertEq(
            harness.getNextSqrtPriceFromInput(Q96, 1, 0, true),
            Q96
        );
    }

    /// @notice getNextSqrtPriceFromInput invalid params revert
    function testGetNextSqrtPriceFromInputReverts() public {
        vm.expectRevert();
        harness.getNextSqrtPriceFromInput(0, 1, 1, true);
        vm.expectRevert();
        harness.getNextSqrtPriceFromInput(Q96, 0, 1, false);
    }

    /// @notice getNextSqrtPriceFromOutput removal for token0
    function testGetNextSqrtPriceFromOutputZeroForOne() public view {
        uint160 next = harness.getNextSqrtPriceFromOutput(Q96, 2, 1, true);
        assertEq(next, Q96 >> 1);
    }

    /// @notice getNextSqrtPriceFromOutput removal for token1
    function testGetNextSqrtPriceFromOutputOneForZero() public view {
        uint160 next = harness.getNextSqrtPriceFromOutput(Q96, 2, 1, false);
        assertEq(next, Q96 << 1);
    }

    /// @notice getAmount0Delta unsigned floor and ceil
    function testGetAmount0DeltaUnsigned() public view {
        uint160 a = Q96;
        uint160 b = Q96 << 1; // 2*Q96
        uint128 liq = 1;
        // floor: (b-a)/(b*a) * liq -> (Q96)/(2*Q96*Q96) = 1/(2*Q96) -> floor = 0
        assertEq(harness.getAmount0DeltaUnsigned(a, b, liq, false), 0);
        // ceil: should be 1
        assertEq(harness.getAmount0DeltaUnsigned(a, b, liq, true), 1);
    }

    /// @notice getAmount1Delta unsigned floor and ceil
    function testGetAmount1DeltaUnsigned() public view {
        uint160 a = Q96;
        uint160 b = Q96 << 1;
        uint128 liq = 1;
        // (b-a)*liq/Q96 = Q96/Q96 = 1
        assertEq(harness.getAmount1DeltaUnsigned(a, b, liq, false), 1);
        assertEq(harness.getAmount1DeltaUnsigned(a, b, liq, true), 1);
    }

    /// @notice getAmount0Delta signed
    function testGetAmount0DeltaSigned() public view {
        uint160 a = Q96;
        uint160 b = Q96 << 1;
        // positive liquidity
        assertEq(harness.getAmount0DeltaSigned(a, b, int128(1)), 1);
        // negative liquidity
        assertEq(harness.getAmount0DeltaSigned(a, b, int128(-1)), -int256(0));
    }

    /// @notice getAmount1Delta signed
    function testGetAmount1DeltaSigned() public view {
        uint160 a = Q96;
        uint160 b = Q96 << 1;
        assertEq(harness.getAmount1DeltaSigned(a, b, int128(1)), 1);
        assertEq(harness.getAmount1DeltaSigned(a, b, int128(-1)), -int256(1));
    }
}
