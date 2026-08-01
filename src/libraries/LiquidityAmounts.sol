// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@evx-core/libraries/FullMath.sol';
import '@evx-core/libraries/FixedPoint96.sol';

/**
 * @title LiquidityAmounts
 * @notice Provides utility functions for calculating liquidity amounts based on token quantities and price ranges.
 * @dev Uses Q96 fixed-point math for precision. Assumes sqrt prices are expressed as Q64.96 values.
 */
library LiquidityAmounts {
    /**
     * @notice Safely downcasts a uint256 to uint128.
     * @dev Reverts if the input doesn't fit in 128 bits.
     * @param x The uint256 value to downcast.
     * @return y The downcasted uint128 value.
     */
    function toUint128(uint256 x) private pure returns (uint128 y) {
        require((y = uint128(x)) == x);
    }

    /**
     * @notice Computes liquidity amount for a given token0 amount and price range.
     * @dev Uses the formula: amount0 * sqrtA * sqrtB / (sqrtB - sqrtA).
     * @param sqrtRatioAX96 The sqrt price at the lower boundary (Q64.96).
     * @param sqrtRatioBX96 The sqrt price at the upper boundary (Q64.96).
     * @param amount0 The amount of token0.
     * @return liquidity The calculated liquidity amount.
     */
    function getLiquidityForAmount0(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount0
    ) internal pure returns (uint128 liquidity) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        uint256 intermediate = FullMath.mulDiv(sqrtRatioAX96, sqrtRatioBX96, FixedPoint96.Q96);
        return toUint128(FullMath.mulDiv(amount0, intermediate, sqrtRatioBX96 - sqrtRatioAX96));
    }

    /**
     * @notice Computes liquidity amount for a given token1 amount and price range.
     * @dev Uses the formula: amount1 / (sqrtB - sqrtA).
     * @param sqrtRatioAX96 The sqrt price at the lower boundary (Q64.96).
     * @param sqrtRatioBX96 The sqrt price at the upper boundary (Q64.96).
     * @param amount1 The amount of token1.
     * @return liquidity The calculated liquidity amount.
     */
    function getLiquidityForAmount1(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount1
    ) internal pure returns (uint128 liquidity) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        return toUint128(FullMath.mulDiv(amount1, FixedPoint96.Q96, sqrtRatioBX96 - sqrtRatioAX96));
    }

    /**
     * @notice Computes the maximum liquidity that can be obtained for given amounts of token0 and token1.
     * @dev Decides how much of each token contributes based on the current price.
     * @param sqrtRatioX96 The current sqrt price of the pool (Q64.96).
     * @param sqrtRatioAX96 The sqrt price at the lower boundary (Q64.96).
     * @param sqrtRatioBX96 The sqrt price at the upper boundary (Q64.96).
     * @param amount0 The amount of token0.
     * @param amount1 The amount of token1.
     * @return liquidity The maximum liquidity that can be minted.
     */
    function getLiquidityForAmounts(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount0,
        uint256 amount1
    ) internal pure returns (uint128 liquidity) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        if (sqrtRatioX96 <= sqrtRatioAX96) {
            liquidity = getLiquidityForAmount0(sqrtRatioAX96, sqrtRatioBX96, amount0);
        } else if (sqrtRatioX96 < sqrtRatioBX96) {
            uint128 liquidity0 = getLiquidityForAmount0(sqrtRatioX96, sqrtRatioBX96, amount0);
            uint128 liquidity1 = getLiquidityForAmount1(sqrtRatioAX96, sqrtRatioX96, amount1);
            liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
        } else {
            liquidity = getLiquidityForAmount1(sqrtRatioAX96, sqrtRatioBX96, amount1);
        }
    }

    /**
     * @notice Computes the amount of token0 for a given liquidity and price range.
     * @dev Uses the formula: liquidity * (sqrtB - sqrtA) / (sqrtB * sqrtA) * 2^96.
     * @param sqrtRatioAX96 The sqrt price at the lower boundary (Q64.96).
     * @param sqrtRatioBX96 The sqrt price at the upper boundary (Q64.96).
     * @param liquidity The amount of liquidity.
     * @return amount0 The equivalent amount of token0.
     */
    function getAmount0ForLiquidity(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount0) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        return
            FullMath.mulDiv(
                uint256(liquidity) << FixedPoint96.RESOLUTION,
                sqrtRatioBX96 - sqrtRatioAX96,
                sqrtRatioBX96
            ) / sqrtRatioAX96;
    }

    /**
     * @notice Computes the amount of token1 for a given liquidity and price range.
     * @dev Uses the formula: liquidity * (sqrtB - sqrtA) / Q96.
     * @param sqrtRatioAX96 The sqrt price at the lower boundary (Q64.96).
     * @param sqrtRatioBX96 The sqrt price at the upper boundary (Q64.96).
     * @param liquidity The amount of liquidity.
     * @return amount1 The equivalent amount of token1.
     */
    function getAmount1ForLiquidity(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount1) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        return FullMath.mulDiv(liquidity, sqrtRatioBX96 - sqrtRatioAX96, FixedPoint96.Q96);
    }

    /**
     * @notice Computes the amounts of token0 and token1 for a given liquidity based on current and boundary prices.
     * @dev Splits liquidity value across both tokens depending on current sqrt ratio.
     * @param sqrtRatioX96 The current sqrt price of the pool (Q64.96).
     * @param sqrtRatioAX96 The sqrt price at the lower boundary (Q64.96).
     * @param sqrtRatioBX96 The sqrt price at the upper boundary (Q64.96).
     * @param liquidity The amount of liquidity.
     * @return amount0 The equivalent amount of token0.
     * @return amount1 The equivalent amount of token1.
     */
    function getAmountsForLiquidity(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        if (sqrtRatioX96 <= sqrtRatioAX96) {
            amount0 = getAmount0ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity);
        } else if (sqrtRatioX96 < sqrtRatioBX96) {
            amount0 = getAmount0ForLiquidity(sqrtRatioX96, sqrtRatioBX96, liquidity);
            amount1 = getAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioX96, liquidity);
        } else {
            amount1 = getAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity);
        }
    }
}
