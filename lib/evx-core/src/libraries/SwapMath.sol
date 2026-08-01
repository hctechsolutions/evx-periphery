// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FullMath.sol";
import "./SqrtPriceMath.sol";

/**
 * @title SwapMath
 * @notice Library for computing the result of a swap within a single tick range.
 * @dev Performs calculations to determine the next price, input/output amounts, and fees for a swap step.
 */
library SwapMath {
    /**
     * @notice Computes the result of a swap step given price limits, liquidity, and remaining input/output.
     * @dev If `amountRemaining` is positive, this function computes how much input token is needed and how far the price moves.
     *      If `amountRemaining` is negative, it computes how much output token can be extracted and the resulting price.
     *      The function also handles rounding and fee computation according to the swap direction and amount type.
     * @param sqrtRatioCurrentX96 The current sqrt price (Q64.96 format) of the pool before the swap step.
     * @param sqrtRatioTargetX96 The target sqrt price that cannot be exceeded (used to determine direction).
     * @param liquidity The available liquidity during this step.
     * @param amountRemaining The amount of input or output remaining to be used (positive = exact input, negative = exact output).
     * @param feePips The fee in hundredths of a bip (1e-6) taken from the input amount.
     * @return sqrtRatioNextX96 The updated sqrt price after the step, bounded by the target.
     * @return amountIn The amount of input token used during this step.
     * @return amountOut The amount of output token returned during this step.
     * @return feeAmount The fee amount deducted from the input.
     */
    function computeSwapStep(
        uint160 sqrtRatioCurrentX96,
        uint160 sqrtRatioTargetX96,
        uint128 liquidity,
        int256 amountRemaining,
        uint24 feePips
    )
        internal
        pure
        returns (
            uint160 sqrtRatioNextX96,
            uint256 amountIn,
            uint256 amountOut,
            uint256 feeAmount
        )
    {
        bool zeroForOne = sqrtRatioCurrentX96 >= sqrtRatioTargetX96;
        bool exactIn = amountRemaining >= 0;

        if (exactIn) {
            // Reduce the input amount by the fee before computing price movement
            uint256 amountRemainingLessFee = FullMath.mulDiv(uint256(amountRemaining), 1e6 - feePips, 1e6);
            amountIn = zeroForOne
                ? SqrtPriceMath.getAmount0Delta(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity, true)
                : SqrtPriceMath.getAmount1Delta(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity, true);

            if (amountRemainingLessFee >= amountIn) {
                sqrtRatioNextX96 = sqrtRatioTargetX96;
            } else {
                sqrtRatioNextX96 = SqrtPriceMath.getNextSqrtPriceFromInput(
                    sqrtRatioCurrentX96,
                    liquidity,
                    amountRemainingLessFee,
                    zeroForOne
                );
            }
        } else {
            // Compute how much output is needed to reach the target price
            amountOut = zeroForOne
                ? SqrtPriceMath.getAmount1Delta(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity, false)
                : SqrtPriceMath.getAmount0Delta(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity, false);

            if (uint256(-amountRemaining) >= amountOut) {
                sqrtRatioNextX96 = sqrtRatioTargetX96;
            } else {
                sqrtRatioNextX96 = SqrtPriceMath.getNextSqrtPriceFromOutput(
                    sqrtRatioCurrentX96,
                    liquidity,
                    uint256(-amountRemaining),
                    zeroForOne
                );
            }
        }

        bool max = sqrtRatioTargetX96 == sqrtRatioNextX96;

        // Recalculate actual amounts used/output based on where the price settled
        if (zeroForOne) {
            amountIn = max && exactIn
                ? amountIn
                : SqrtPriceMath.getAmount0Delta(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, true);
            amountOut = max && !exactIn
                ? amountOut
                : SqrtPriceMath.getAmount1Delta(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, false);
        } else {
            amountIn = max && exactIn
                ? amountIn
                : SqrtPriceMath.getAmount1Delta(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, true);
            amountOut = max && !exactIn
                ? amountOut
                : SqrtPriceMath.getAmount0Delta(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, false);
        }

        // Adjust output if it exceeds the amount specified
        if (!exactIn && amountOut > uint256(-amountRemaining)) {
            amountOut = uint256(-amountRemaining);
        }

        // Calculate fee based on effective input
        if (exactIn && sqrtRatioNextX96 != sqrtRatioTargetX96) {
            feeAmount = uint256(amountRemaining) - amountIn;
        } else {
            feeAmount = FullMath.mulDivRoundingUp(amountIn, feePips, 1e6 - feePips);
        }
    }
}
