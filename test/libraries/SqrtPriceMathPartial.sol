// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {SqrtPriceMathPartial} from "@evx-periphery/libraries/SqrtPriceMathPartial.sol";
import {FixedPoint96} from "@evx-core/libraries/FixedPoint96.sol";
import {UnsafeMath} from "@evx-core/libraries/UnsafeMath.sol";
import {FullMath} from "@evx-core/libraries/FullMath.sol";


/**
 * @title SqrtPriceMathPartialTest
 * @notice Unit tests for getAmount0Delta / getAmount1Delta helpers.
 */
contract SqrtWrapper {
    function amt0(
        uint160 sa, uint160 sb, uint128 liq, bool up
    ) external pure returns (uint256) {
        return SqrtPriceMathPartial.getAmount0Delta(sa, sb, liq, up);
    }

    function amt1(
        uint160 sa, uint160 sb, uint128 liq, bool up
    ) external pure returns (uint256) {
        return SqrtPriceMathPartial.getAmount1Delta(sa, sb, liq, up);
    }
}

contract SqrtPriceMathPartialTest is Test {
    SqrtWrapper internal wrap;

    uint160 internal constant Q96 = uint160(FixedPoint96.Q96);

    // Test numbers: sqrtA = 1.0, sqrtB = 2.0  (exact powers of 2 simplify maths)
    uint160 internal constant SA = Q96;
    uint160 internal constant SB = Q96 * 2;

    uint128 internal constant LIQ = 1_000_000; // 1e6

    function setUp() public {
        wrap = new SqrtWrapper();
    }

    /**
     * Formula with our numbers: amount0 = liquidity / 2  = 500 000.
     * Checks both rounding modes (should be equal on exact integer result).
     */
    function testAmount0Exact() external pure {
        uint256 down =
            SqrtPriceMathPartial.getAmount0Delta(SA, SB, LIQ, false);
        uint256 up   =
            SqrtPriceMathPartial.getAmount0Delta(SA, SB, LIQ, true);

        assertEq(down, LIQ / 2, "down value mismatch");
        assertEq(up,   down,    "up should equal down");
    }

    /**
     * Reversing the order of inputs must yield the same result.
     */
    function testAmount0OrderAgnostic() external pure {
        uint256 normal =
            SqrtPriceMathPartial.getAmount0Delta(SA, SB, LIQ, false);
        uint256 reversed =
            SqrtPriceMathPartial.getAmount0Delta(SB, SA, LIQ, false);

        assertEq(normal, reversed, "order should not matter");
    }

    /**
     * Path requiring rounding-up:
     *   sqrtA = 1.0, sqrtB = 1.5  =>  expected ~666 667 (ceil).
     */
    function testAmount0RoundUp() external pure {
        uint160 sb = Q96 * 3 / 2;                  // 1.5
        uint256 down =
            SqrtPriceMathPartial.getAmount0Delta(SA, sb, LIQ, false);
        uint256 up   =
            SqrtPriceMathPartial.getAmount0Delta(SA, sb, LIQ, true);

        assertEq(up, down + 1, "round-up should add one unit");
    }

    /**
     * sqrtRatioAX96 = 0 must revert.
     */
    function testAmount0RevertsOnZeroSqrt() external {
        vm.expectRevert();
        wrap.amt0(0, SB, LIQ, false);
    }

    /**
     * With our numbers amount1 = liquidity.
     */
    function testAmount1Exact() external pure {
        uint256 down =
            SqrtPriceMathPartial.getAmount1Delta(SA, SB, LIQ, false);
        uint256 up   =
            SqrtPriceMathPartial.getAmount1Delta(SA, SB, LIQ, true);

        assertEq(down, LIQ, "down value mismatch");
        assertEq(up,   LIQ, "up should equal exact value");
    }

    /**
     * Rounding-up path where fractional result exists.
     */
    function testAmount1RoundUp() external pure {
        uint160 sb  = Q96 * 3 / 2;     // 1.5
        uint128 liq = 1;               // choose an odd liquidity so division has remainder

        uint256 down = SqrtPriceMathPartial.getAmount1Delta(SA, sb, liq, false);
        uint256 up = SqrtPriceMathPartial.getAmount1Delta(SA, sb, liq, true);

        assertEq(up, down + 1, "round-up should add one unit");
    }
}
