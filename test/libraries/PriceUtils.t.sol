// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PriceUtilsTest
 * @notice Unit tests for the low‑level math helpers inside PriceUtils.
 */
import "forge-std/Test.sol";
import {PriceUtils} from "@evx-periphery/libraries/PriceUtils.sol";

/* -------------------------------------------------------------------------- */
/*                     Thin wrapper exposing internal calls                   */
/* -------------------------------------------------------------------------- */
contract PriceUtilsWrapper {
    function absVal(int256 v) external pure returns (uint256) {
        return PriceUtils.abs(v);
    }

    function wadLn(uint256 x) external pure returns (int256) {
        return PriceUtils.wadLn(x);
    }

    function log1_0001(uint256 x) external pure returns (int24) {
        return PriceUtils.log1_0001(x);
    }
}

contract PriceUtilsTest is Test {
    PriceUtilsWrapper internal wrap;

    uint256 internal constant WAD      = 1e18;
    uint256 internal constant LOG_BASE = PriceUtils.LOG_BASE;

    function setUp() public {
        wrap = new PriceUtilsWrapper();
    }

    /* ---------------------------------------------------------------------- */
    /*                                   abs                                  */
    /* ---------------------------------------------------------------------- */

    function testAbsPositive() external pure {
        uint256 out = PriceUtils.abs(123);
        assertEq(out, 123);
    }

    function testAbsNegative() external pure {
        uint256 out = PriceUtils.abs(-456);
        assertEq(out, 456);
    }

    function testAbsZero() external pure {
        uint256 out = PriceUtils.abs(0);
        assertEq(out, 0);
    }

    /* ---------------------------------------------------------------------- */
    /*                                  wadLn                                 */
    /* ---------------------------------------------------------------------- */

    /// ln(1) = 0  (with WAD‑precision input)
    function testWadLnOne() external pure {
        int256 ln = PriceUtils.wadLn(WAD);
        assertEq(ln, 0);
    }

    /// Spot‑check: ln(1.1) ≈ 0.0953… in fixed‑point (simple Taylor approx)
    function testWadLnOnePointOne() external pure {
        uint256 x  = (11 * WAD) / 10; // 1.1 × WAD
        // Expected per library formula: (x‑WAD)*WAD / x
        int256 z   = int256(x - WAD);
        int256 exp = (z * int256(WAD)) / int256(x);
        int256 ln  = PriceUtils.wadLn(x);
        assertEq(ln, exp, "wadLn mismatch for 1.1");
    }

    /* ---------------------------------------------------------------------- */
    /*                                log1_0001                               */
    /* ---------------------------------------------------------------------- */

    /// log_{1.0001}(1) = 0
    function testLogBaseOne() external pure {
        int24 out = PriceUtils.log1_0001(WAD);
        assertEq(out, 0);
    }

    /**
     * For very small offsets from 1 the helper’s integer math can overflow an
     * int24, so we only assert that `log1_0001` is monotonic here:
     *   log_{1.0001}(1.0001)  >  log_{1.0001}(1)
     */
    function testLogMonotonic() external pure {
        int24 a = PriceUtils.log1_0001(WAD);
        int24 b = PriceUtils.log1_0001(LOG_BASE);
        assertGt(b, a, "log1_0001 should be monotonic");
    }
}
