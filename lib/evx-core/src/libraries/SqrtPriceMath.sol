// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LowGasSafeMath.sol";
import "./SafeCast.sol";

import "./FullMath.sol";
import "./UnsafeMath.sol";
import "./FixedPoint96.sol";

/**
 * @title SqrtPriceMath
 * @notice Library for computing price and amount deltas using Q64.96 sqrt price and liquidity.
 * @dev Used for precise math around liquidity changes and swap steps.
 */
library SqrtPriceMath {
    using LowGasSafeMath for uint256;
    using SafeCast for uint256;

    /**
     * @notice Computes the next sqrt price given a token0 delta.
     * @dev Always rounds up to avoid crossing boundaries or providing excess output.
     *      Uses either the lossless formula or a fallback for precision-constrained environments.
     * @param sqrtPX96 The current sqrt price (Q64.96 format).
     * @param liquidity The current pool liquidity.
     * @param amount The amount of token0 to add or remove.
     * @param add Whether to add or subtract the amount.
     * @return The new sqrt price after the update.
     */
    function getNextSqrtPriceFromAmount0RoundingUp(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 amount,
        bool add
    ) internal pure returns (uint160) {
        // we short circuit amount == 0 because the result is otherwise not guaranteed to equal the input price
        if (amount == 0) return sqrtPX96;
        uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;

        if (add) {
            uint256 product;
            if ((product = amount * sqrtPX96) / amount == sqrtPX96) {
                uint256 denominator = numerator1 + product;
                if (denominator >= numerator1)
                    // always fits in 160 bits
                    return uint160(FullMath.mulDivRoundingUp(numerator1, sqrtPX96, denominator));
            }

            return uint160(UnsafeMath.divRoundingUp(numerator1, (numerator1 / sqrtPX96).add(amount)));
        } else {
            uint256 product;
            // if the product overflows, we know the denominator underflows
            // in addition, we must check that the denominator does not underflow
            require((product = amount * sqrtPX96) / amount == sqrtPX96 && numerator1 > product);
            uint256 denominator = numerator1 - product;
            return FullMath.mulDivRoundingUp(numerator1, sqrtPX96, denominator).toUint160();
        }
    }

    /**
     * @notice Computes the next sqrt price given a token1 delta.
     * @dev Always rounds down to avoid passing the target price.
     *      Efficiently handles most inputs with a simple shift/divide fallback to full precision.
     * @param sqrtPX96 The current sqrt price (Q64.96 format).
     * @param liquidity The current pool liquidity.
     * @param amount The amount of token1 to add or remove.
     * @param add Whether to add or subtract the amount.
     * @return The new sqrt price after the update.
     */
    function getNextSqrtPriceFromAmount1RoundingDown(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 amount,
        bool add
    ) internal pure returns (uint160) {
        // if we're adding (subtracting), rounding down requires rounding the quotient down (up)
        // in both cases, avoid a mulDiv for most inputs
        if (add) {
            uint256 quotient =
                (
                    amount <= type(uint160).max
                        ? (amount << FixedPoint96.RESOLUTION) / liquidity
                        : FullMath.mulDiv(amount, FixedPoint96.Q96, liquidity)
                );

            return uint256(sqrtPX96).add(quotient).toUint160();
        } else {
            uint256 quotient =
                (
                    amount <= type(uint160).max
                        ? UnsafeMath.divRoundingUp(amount << FixedPoint96.RESOLUTION, liquidity)
                        : FullMath.mulDivRoundingUp(amount, FixedPoint96.Q96, liquidity)
                );

            require(sqrtPX96 > quotient);
            // always fits 160 bits
            return uint160(sqrtPX96 - quotient);
        }
    }

    /**
     * @notice Calculates the next sqrt price from a given token0 or token1 input amount.
     * @dev Reverts if inputs are invalid or if next price is out of bounds.
     * @param sqrtPX96 The current sqrt price.
     * @param liquidity The current pool liquidity.
     * @param amountIn The amount being added.
     * @param zeroForOne True if token0 is being swapped in.
     * @return sqrtQX96 The updated sqrt price.
     */
    function getNextSqrtPriceFromInput(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) internal pure returns (uint160 sqrtQX96) {
        require(sqrtPX96 > 0);
        require(liquidity > 0);

        // round to make sure that we don't pass the target price
        return
            zeroForOne
                ? getNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountIn, true)
                : getNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountIn, true);
    }

    /**
     * @notice Calculates the next sqrt price from a given token0 or token1 output amount.
     * @dev Reverts if inputs are invalid or if next price is out of bounds.
     * @param sqrtPX96 The current sqrt price.
     * @param liquidity The current pool liquidity.
     * @param amountOut The amount being removed.
     * @param zeroForOne True if token0 is being swapped out.
     * @return sqrtQX96 The updated sqrt price.
     */
    function getNextSqrtPriceFromOutput(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 amountOut,
        bool zeroForOne
    ) internal pure returns (uint160 sqrtQX96) {
        require(sqrtPX96 > 0);
        require(liquidity > 0);

        // round to make sure that we pass the target price
        return
            zeroForOne
                ? getNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountOut, false)
                : getNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountOut, false);
    }

    /**
     * @notice Computes amount0 delta between two sqrt prices.
     * @dev Computes liquidity * (sqrtB - sqrtA) / (sqrtB * sqrtA).
     * @param sqrtRatioAX96 First sqrt price.
     * @param sqrtRatioBX96 Second sqrt price.
     * @param liquidity Liquidity amount.
     * @param roundUp Whether to round the result up.
     * @return amount0 The delta in token0.
     */
    function getAmount0Delta(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount0) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;
        uint256 numerator2 = sqrtRatioBX96 - sqrtRatioAX96;

        require(sqrtRatioAX96 > 0);

        return
            roundUp
                ? UnsafeMath.divRoundingUp(
                    FullMath.mulDivRoundingUp(numerator1, numerator2, sqrtRatioBX96),
                    sqrtRatioAX96
                )
                : FullMath.mulDiv(numerator1, numerator2, sqrtRatioBX96) / sqrtRatioAX96;
    }

    /**
     * @notice Computes amount1 delta between two sqrt prices.
     * @dev Computes liquidity * (sqrtB - sqrtA).
     * @param sqrtRatioAX96 First sqrt price.
     * @param sqrtRatioBX96 Second sqrt price.
     * @param liquidity Liquidity amount.
     * @param roundUp Whether to round the result up.
     * @return amount1 The delta in token1.
     */
    function getAmount1Delta(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount1) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        return
            roundUp
                ? FullMath.mulDivRoundingUp(liquidity, sqrtRatioBX96 - sqrtRatioAX96, FixedPoint96.Q96)
                : FullMath.mulDiv(liquidity, sqrtRatioBX96 - sqrtRatioAX96, FixedPoint96.Q96);
    }

    /**
     * @notice Signed wrapper to compute token0 delta for a signed liquidity change.
     * @param sqrtRatioAX96 First sqrt price.
     * @param sqrtRatioBX96 Second sqrt price.
     * @param liquidity Signed liquidity delta.
     * @return amount0 The signed token0 delta.
     */
    function getAmount0Delta(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        int128 liquidity
    ) internal pure returns (int256 amount0) {
        return
            liquidity < 0
                ? -getAmount0Delta(sqrtRatioAX96, sqrtRatioBX96, uint128(-liquidity), false).toInt256()
                : getAmount0Delta(sqrtRatioAX96, sqrtRatioBX96, uint128(liquidity), true).toInt256();
    }

    /**
     * @notice Signed wrapper to compute token1 delta for a signed liquidity change.
     * @param sqrtRatioAX96 First sqrt price.
     * @param sqrtRatioBX96 Second sqrt price.
     * @param liquidity Signed liquidity delta.
     * @return amount1 The signed token1 delta.
     */
    function getAmount1Delta(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        int128 liquidity
    ) internal pure returns (int256 amount1) {
        return
            liquidity < 0
                ? -getAmount1Delta(sqrtRatioAX96, sqrtRatioBX96, uint128(-liquidity), false).toInt256()
                : getAmount1Delta(sqrtRatioAX96, sqrtRatioBX96, uint128(liquidity), true).toInt256();
    }
}
