// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SwapMath} from "@evx-core/libraries/SwapMath.sol";
import {TickMath} from "@evx-core/libraries/TickMath.sol";
import {LiquidityMath} from "@evx-core/libraries/LiquidityMath.sol";
import {SafeCast} from "@evx-core/libraries/SafeCast.sol";

/// @notice SwapMath.computeSwapStep loop used as the quote reference (not the Quoter, not a price oracle).
/// @dev Independent of Quoter.sol. Mirrors EvxPool.swap step semantics for a single minted range.
library QuoteSwapMathRef {
    using SafeCast for uint256;

    struct Range {
        int24 lo;
        int24 hi;
        uint128 liquidity;
    }

    struct Result {
        uint256 amountIn;
        uint256 amountOut;
        uint256 feePaid;
        uint160 sqrtPriceX96;
        int24 tick;
        uint128 liquidity;
    }

    struct StepState {
        int256 amountSpecified;
        int256 remaining;
        int256 calculated;
        uint160 limit;
        uint256 feeAcc;
        uint128 L;
        uint160 sqrtP;
        int24 t;
        bool zeroForOne;
        bool exactIn;
        uint24 fee;
    }

    function simulate(
        uint160 sqrtPriceX96,
        int24 tick,
        uint128 liquidity,
        uint24 fee,
        bool zeroForOne,
        bool exactIn,
        uint256 amount,
        Range memory range
    ) internal pure returns (Result memory r) {
        StepState memory s;
        s.amountSpecified = exactIn ? amount.toInt256() : -amount.toInt256();
        s.remaining = s.amountSpecified;
        s.limit = zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;
        s.L = liquidity;
        s.sqrtP = sqrtPriceX96;
        s.t = tick;
        s.zeroForOne = zeroForOne;
        s.exactIn = exactIn;
        s.fee = fee;

        _loop(s, range);
        _fillAmounts(s, r);
        r.feePaid = s.feeAcc;
        r.sqrtPriceX96 = s.sqrtP;
        r.tick = s.t;
        r.liquidity = s.L;
    }

    function _loop(StepState memory s, Range memory range) private pure {
        for (uint256 i = 0; i < 64; ++i) {
            if (s.remaining == 0 || s.sqrtP == s.limit) break;

            (int24 tickNext, bool initialized) = _nextInitialized(s.t, s.zeroForOne, range);
            if (tickNext < TickMath.MIN_TICK) tickNext = TickMath.MIN_TICK;
            if (tickNext > TickMath.MAX_TICK) tickNext = TickMath.MAX_TICK;

            uint160 sqrtNext = TickMath.getSqrtRatioAtTick(tickNext);
            uint160 target = (s.zeroForOne ? sqrtNext < s.limit : sqrtNext > s.limit) ? s.limit : sqrtNext;
            _oneStep(s, range, tickNext, initialized, target, sqrtNext);
        }
    }

    function _oneStep(
        StepState memory s,
        Range memory range,
        int24 tickNext,
        bool initialized,
        uint160 target,
        uint160 sqrtNext
    ) private pure {
        (uint160 sqrtPNew, uint256 stepIn, uint256 stepOut, uint256 feeAmount) =
            SwapMath.computeSwapStep(s.sqrtP, target, s.L, s.remaining, s.fee);

        if (s.exactIn) {
            s.remaining -= (stepIn + feeAmount).toInt256();
            s.calculated -= stepOut.toInt256();
        } else {
            s.remaining += stepOut.toInt256();
            s.calculated += (stepIn + feeAmount).toInt256();
        }
        s.feeAcc += feeAmount;

        uint160 sqrtStart = s.sqrtP;
        s.sqrtP = sqrtPNew;

        if (s.sqrtP == sqrtNext) {
            if (initialized) {
                int128 net = _netAt(tickNext, range);
                if (s.zeroForOne) net = -net;
                s.L = LiquidityMath.addDelta(s.L, net);
            }
            s.t = s.zeroForOne ? tickNext - 1 : tickNext;
        } else if (s.sqrtP != sqrtStart) {
            s.t = TickMath.getTickAtSqrtRatio(s.sqrtP);
        }
    }

    function _fillAmounts(StepState memory s, Result memory r) private pure {
        int256 amount0;
        int256 amount1;
        if (s.zeroForOne == s.exactIn) {
            amount0 = s.amountSpecified - s.remaining;
            amount1 = s.calculated;
        } else {
            amount0 = s.calculated;
            amount1 = s.amountSpecified - s.remaining;
        }
        r.amountIn = amount0 > 0 ? uint256(amount0) : uint256(amount1);
        r.amountOut = amount0 < 0 ? uint256(-amount0) : uint256(-amount1);
    }

    function _nextInitialized(int24 tick, bool zeroForOne, Range memory range)
        private
        pure
        returns (int24 next, bool initialized)
    {
        if (zeroForOne) {
            if (tick > range.hi) return (range.hi, true);
            if (tick > range.lo) return (range.lo, true);
            return (TickMath.MIN_TICK, false);
        } else {
            if (tick < range.lo) return (range.lo, true);
            if (tick < range.hi) return (range.hi, true);
            return (TickMath.MAX_TICK, false);
        }
    }

    function _netAt(int24 tick, Range memory range) private pure returns (int128) {
        if (tick == range.lo) return int128(uint128(range.liquidity));
        if (tick == range.hi) return -int128(uint128(range.liquidity));
        return 0;
    }
}
