// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FixedPoint96} from "@evx-core/libraries/FixedPoint96.sol";
import {QuoteSwapMathRef} from "../libraries/QuoteSwapMathRef.sol";

/// @notice Versioned normative quote fixture (oracle). Bump VERSION when a vector changes purpose.
/// @dev Expected amounts are filled from QuoteSwapMathRef on the same initial state; they are not
///      copied from illustrative docs and are not OracleLibrary.getQuoteAtTick.
library QuoteVectors {
    uint256 internal constant VERSION = 1;

    struct Vector {
        string id;
        bool exactIn;
        bool zeroForOne;
        uint24 fee;
        int24 tickSpacing;
        uint160 sqrtPriceX96;
        int24 tick;
        QuoteSwapMathRef.Range range;
        uint256 amountIn;
        uint256 amountOut;
        uint256 expectedAmountIn;
        uint256 expectedAmountOut;
        uint256 expectedFee;
        uint256 toleranceWei;
        bool hasExpectedState;
        uint160 expectedSqrtPriceX96;
        int24 expectedTick;
        uint128 expectedLiquidity;
        bool committed;
    }

    function tick0ExactIn0For1() internal pure returns (Vector memory v) {
        v.id = "tick0-exact-in-0for1";
        v.exactIn = true;
        v.zeroForOne = true;
        v.fee = 3000;
        v.tickSpacing = 60;
        v.sqrtPriceX96 = uint160(FixedPoint96.Q96);
        v.tick = 0;
        v.range = QuoteSwapMathRef.Range({lo: -60000, hi: 60000, liquidity: 1e18});
        v.amountIn = 1e6;
        v.toleranceWei = 0;
        v.committed = true;
        v.expectedAmountIn = 1000000;
        v.expectedAmountOut = 996999;
        v.expectedFee = 3000;
    }

    function tick0ExactIn1For0() internal pure returns (Vector memory v) {
        v.id = "tick0-exact-in-1for0";
        v.exactIn = true;
        v.zeroForOne = false;
        v.fee = 3000;
        v.tickSpacing = 60;
        v.sqrtPriceX96 = uint160(FixedPoint96.Q96);
        v.tick = 0;
        v.range = QuoteSwapMathRef.Range({lo: -60000, hi: 60000, liquidity: 1e18});
        v.amountIn = 1e6;
        v.toleranceWei = 0;
        v.committed = true;
        v.expectedAmountIn = 1000000;
        v.expectedAmountOut = 996999;
        v.expectedFee = 3000;
    }

    function tick0ExactOut0For1() internal pure returns (Vector memory v) {
        v.id = "tick0-exact-out-0for1";
        v.exactIn = false;
        v.zeroForOne = true;
        v.fee = 3000;
        v.tickSpacing = 60;
        v.sqrtPriceX96 = uint160(FixedPoint96.Q96);
        v.tick = 0;
        v.range = QuoteSwapMathRef.Range({lo: -60000, hi: 60000, liquidity: 1e18});
        v.amountOut = 1e6;
        v.toleranceWei = 0;
        v.committed = true;
        v.expectedAmountIn = 1003011;
        v.expectedAmountOut = 1000000;
        v.expectedFee = 3010;
    }

    function tick0ExactOut1For0() internal pure returns (Vector memory v) {
        v.id = "tick0-exact-out-1for0";
        v.exactIn = false;
        v.zeroForOne = false;
        v.fee = 3000;
        v.tickSpacing = 60;
        v.sqrtPriceX96 = uint160(FixedPoint96.Q96);
        v.tick = 0;
        v.range = QuoteSwapMathRef.Range({lo: -60000, hi: 60000, liquidity: 1e18});
        v.amountOut = 1e6;
        v.toleranceWei = 0;
        v.committed = true;
        v.expectedAmountIn = 1003011;
        v.expectedAmountOut = 1000000;
        v.expectedFee = 3010;
    }

    function tickCrossExactIn1For0() internal pure returns (Vector memory v) {
        v.id = "tick-cross-exact-in-1for0";
        v.exactIn = true;
        v.zeroForOne = false;
        v.fee = 3000;
        v.tickSpacing = 60;
        v.sqrtPriceX96 = uint160(FixedPoint96.Q96);
        v.tick = 0;
        v.range = QuoteSwapMathRef.Range({lo: -60, hi: 60, liquidity: 1e18});
        v.amountIn = 1e18;
        v.toleranceWei = 0;
        v.hasExpectedState = true;
        v.committed = true;
        v.expectedAmountIn = 3013394245478362;
        v.expectedAmountOut = 2995354955910780;
        v.expectedFee = 9040182736436;
        v.expectedSqrtPriceX96 = 1461446703485210103287273052203988822378723970341;
        v.expectedTick = 887271;
        v.expectedLiquidity = 0;
    }

    function exactInOverquoteThin() internal pure returns (Vector memory v) {
        v.id = "exact-in-overquote-thin";
        v.exactIn = true;
        v.zeroForOne = true;
        v.fee = 3000;
        v.tickSpacing = 60;
        v.sqrtPriceX96 = uint160(FixedPoint96.Q96);
        v.tick = 0;
        v.range = QuoteSwapMathRef.Range({lo: -60, hi: 60, liquidity: 1e12});
        v.amountIn = 100e18;
        v.toleranceWei = 0;
        v.committed = true;
        v.expectedAmountIn = 3013394246;
        v.expectedAmountOut = 2995354955;
        v.expectedFee = 9040183;
    }

    function outOfRangeReachable() internal pure returns (Vector memory v) {
        v.id = "l0-out-of-range-reachable";
        v.exactIn = true;
        v.zeroForOne = false; // price up toward [60, 120]
        v.fee = 3000;
        v.tickSpacing = 60;
        v.sqrtPriceX96 = uint160(FixedPoint96.Q96);
        v.tick = 0;
        v.range = QuoteSwapMathRef.Range({lo: 60, hi: 120, liquidity: 1e18});
        v.amountIn = 1e6;
        v.toleranceWei = 0;
        v.committed = false;
    }
}
