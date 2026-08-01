// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import "forge-std/Test.sol";

import { LiquidityAmounts } from "@evx-periphery/libraries/LiquidityAmounts.sol";
import { FixedPoint96 } from "@evx-core/libraries/FixedPoint96.sol";
import { FullMath } from "@evx-core/libraries/FullMath.sol";

/**
 * @title LiquidityAmountsTest
 * @notice Unit tests for the LiquidityAmounts library
 *         (getLiquidity*  ↔  getAmount* conversion pair).
 *
 * @dev All assertions use hard‑coded expectations where the arithmetic
 *      collapses to simple whole numbers, so the test remains independent
 *      of the library implementation. Internal‑only helpers in a thin wrapper 
 *      so tests can call them.
 */
contract LiquidityWrapper {
    function getLiq0(
        uint160 sa, uint160 sb, uint256 amt0
    ) external pure returns (uint128) {
        return LiquidityAmounts.getLiquidityForAmount0(sa, sb, amt0);
    }

    function getLiq1(
        uint160 sa, uint160 sb, uint256 amt1
    ) external pure returns (uint128) {
        return LiquidityAmounts.getLiquidityForAmount1(sa, sb, amt1);
    }

    function getLiqBoth(
        uint160 sx, uint160 sa, uint160 sb,
        uint256 amt0, uint256 amt1
    ) external pure returns (uint128) {
        return LiquidityAmounts.getLiquidityForAmounts(
            sx, sa, sb, amt0, amt1
        );
    }

    function getAmt0(
        uint160 sa, uint160 sb, uint128 liq
    ) external pure returns (uint256) {
        return LiquidityAmounts.getAmount0ForLiquidity(sa, sb, liq);
    }

    function getAmt1(
        uint160 sa, uint160 sb, uint128 liq
    ) external pure returns (uint256) {
        return LiquidityAmounts.getAmount1ForLiquidity(sa, sb, liq);
    }

    function getBothAmts(
        uint160 sx, uint160 sa, uint160 sb, uint128 liq
    ) external pure returns (uint256,uint256) {
        return LiquidityAmounts.getAmountsForLiquidity(
            sx, sa, sb, liq
        );
    }
}

contract LiquidityAmountsTest is Test {
    LiquidityWrapper internal wrap;

    // Handy aliases
    uint160 internal constant Q96 = uint160(FixedPoint96.Q96);

    /// sqrtPriceA = 1.0  ( Q96 )
    /// sqrtPriceB = 2.0  ( 2 * Q96 )
    uint160 internal constant SA = Q96;
    uint160 internal constant SB = Q96 * 2;

    function setUp() public {
        wrap = new LiquidityWrapper();
    }

    /**
     * @dev For SA = 1×Q96  and SB = 2×Q96:
     *      liquidity = amount0 * 2
     */
    function testLiquidityFromAmount0Simple() external view {
        uint256 amount0  = 1 ether;
        uint128 expected = uint128(amount0 * 2);

        uint128 actual = wrap.getLiq0(SA, SB, amount0);
        assertEq(actual, expected, "liquidity(amt0) mismatch");
    }

    /**
     * @dev For the same boundaries liquidity = amount1 (ratio simplifies to 1).
     */
    function testLiquidityFromAmount1Simple() external view {
        uint256 amount1  = 1 ether;
        uint128 expected = uint128(amount1);

        uint128 actual = wrap.getLiq1(SA, SB, amount1);
        assertEq(actual, expected, "liquidity(amt1) mismatch");
    }

    /**
     * @dev Case 1: current price below range => only token0 matters.
     */
    function testLiquidityFromAmountsBelowRange() external view {
        uint160 sx       = Q96 / 2;          // 0.5 × Q96  (below SA)
        uint256 amt0     = 1 ether;
        uint256 amt1     = 1 ether;          // ignored
        uint128 expected = uint128(amt0 * 2);

        uint128 actual = wrap.getLiqBoth(sx, SA, SB, amt0, amt1);
        assertEq(actual, expected, "liquidity below range mismatch");
    }

    /**
     * @dev Case 2: current price within range => min(liq0, liq1) is chosen.
     *      With our chosen numbers: liq0 = 4/3 * amt0,  liq1 = 2/3 * amt1.
     *      Using amt0 = amt1, liq1 is smaller.
     */
    function testLiquidityFromAmountsInRange() external view {
        uint160 sx   = Q96 * 3 / 2; // 1.5 × Q96
        uint256 amt0 = 3 ether;
        uint256 amt1 = 3 ether;

        // Compute expected manually:
        // liq0 = amt0 * (sx * SB / Q96) / (SB - sx)
        uint256 intermediate = FullMath.mulDiv(sx, SB, Q96);
        uint256 liq0 = FullMath.mulDiv(amt0, intermediate, SB - sx);

        // liq1 = amt1 * Q96 / (sx - SA)
        uint256 liq1 = FullMath.mulDiv(amt1, Q96, sx - SA);

        uint128 expected = uint128(liq0 < liq1 ? liq0 : liq1);

        uint128 actual = wrap.getLiqBoth(sx, SA, SB, amt0, amt1);
        assertEq(actual, expected, "liquidity within range mismatch");
    }

    /**
     * @dev Case 3: current price above range => only token1 matters.
     */
    function testLiquidityFromAmountsAboveRange() external view {
        uint160 sx       = SB * 2;           // 4.0 × Q96
        uint256 amt0     = 1 ether;          // ignored
        uint256 amt1     = 1 ether;
        uint128 expected = uint128(amt1);    // see getLiq1 simplification

        uint128 actual = wrap.getLiqBoth(sx, SA, SB, amt0, amt1);
        assertEq(actual, expected, "liquidity above range mismatch");
    }

    /**
     * @dev Converting liquidity back to amounts (token0 path).
     */
    function testAmount0ForLiquidity() external view  {
        uint128 liq      = 2 ether;
        uint256 expected =
            FullMath.mulDiv(
                uint256(liq) << FixedPoint96.RESOLUTION,
                SB - SA,
                SB
            ) / SA;

        uint256 actual = wrap.getAmt0(SA, SB, liq);
        assertEq(actual, expected, "amount0 mismatch");
    }

    /**
     * @dev Converting liquidity back to amounts (token1 path):  with our numbers,
     *      amount1 = liq (ratio 1:1).
     */
    function testAmount1ForLiquidity() external view {
        uint128 liq      = 1 ether;
        uint256 expected = liq;

        uint256 actual = wrap.getAmt1(SA, SB, liq);
        assertEq(actual, expected, "amount1 mismatch");
    }

    /**
     * @dev When price within range both tokens should be non‑zero and consistent
     *      with the standalone helpers.
     */
    function testAmountsForLiquidityInRange() external view {
        uint160 sx  = Q96 * 3 / 2; // 1.5
        uint128 liq = 1 ether;

        (uint256 amt0, uint256 amt1) = wrap.getBothAmts(sx, SA, SB, liq);

        uint256 exp0 = wrap.getAmt0(sx, SB, liq);
        uint256 exp1 = wrap.getAmt1(SA, sx, liq);

        assertEq(amt0, exp0, "amount0 in range mismatch");
        assertEq(amt1, exp1, "amount1 in range mismatch");
    }
}
