// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { DecimalStringParams } from './NFT/NFTSharedStructs.sol'; 
import '@evx-core/libraries/FullMath.sol';
import '@evx-core/libraries/TickMath.sol';

library PriceUtils {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant LOG_BASE = 1000100000000000000; // 1.0001 * 1e18

    /**
     * @notice Computes the absolute value of a signed integer.
     * @param value The signed integer.
     * @return absValue The absolute value as unsigned integer.
     */
    function abs(int256 value) internal pure returns (uint256 absValue) {
        return uint256(value < 0 ? -value : value);
    }

    /**
     * @notice Returns a WAD-precision logarithm base 1.0001.
     * @param x The input number in WAD.
     * @return result The log base 1.0001 of x.
     */
    function log1_0001(uint256 x) internal pure returns (int24 result) {
        // Natural log base e
        int256 ln = wadLn(x);
        // Change of base formula: log_b(x) = ln(x) / ln(b)
        result = int24(ln * int256(WAD) / int256(wadLn(LOG_BASE)));
    }

    /**
     * @notice Approximates the natural logarithm (ln) using a simple Taylor series (not for production).
     * @dev Assumes input is in WAD (1e18 precision).
     * @param x The input value.
     * @return y The ln of x.
     */
    function wadLn(uint256 x) internal pure returns (int256 y) {
        require(x >= WAD / 10 && x <= WAD * 10, "x out of bounds");
        int256 z = int256(x - WAD);
        y = (z * int256(WAD)) / int256(x);
    }

    /**
     * @notice Converts tick to decimal string representation of price.
     * @dev Uses fixed point math with WAD precision.
     */
    function tickToDecimalString(
        int24 tick,
        int24 tickSpacing,
        uint8 baseTokenDecimals,
        uint8 quoteTokenDecimals,
        bool flipRatio
    ) internal pure returns (string memory) {
        if (tick == (TickMath.MIN_TICK / tickSpacing) * tickSpacing) {
            return !flipRatio ? 'MIN' : 'MAX';
        } else if (tick == (TickMath.MAX_TICK / tickSpacing) * tickSpacing) {
            return !flipRatio ? 'MAX' : 'MIN';
        } else {
            uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(tick);
            if (flipRatio) {
                require(sqrtRatioX96 != 0, "PriceUtils: divide by zero");
                sqrtRatioX96 = uint160((uint256(1) << 192) / sqrtRatioX96);
            }
            return fixedPointToDecimalString(sqrtRatioX96, baseTokenDecimals, quoteTokenDecimals);
        }
    }

    /**
     * @notice Adjusts sqrtRatioX96 for token decimal differences.
     * @dev This function handles decimal scaling and rounding using FullMath for precision.
     * @param sqrtRatioX96 The sqrt price encoded as a Q64.96.
     * @param baseTokenDecimals Number of decimals of the base token.
     * @param quoteTokenDecimals Number of decimals of the quote token.
     * @return adjustedSqrtRatioX96 Adjusted sqrt price considering decimals.
     */
    function adjustForDecimalPrecision(
        uint160 sqrtRatioX96,
        uint8 baseTokenDecimals,
        uint8 quoteTokenDecimals
    ) internal pure returns (uint256 adjustedSqrtRatioX96) {
        uint256 difference = abs(
            int256(uint256(baseTokenDecimals)) - int256(uint256(quoteTokenDecimals))
        );

        uint256 sqrt10X128 = 1076067327063303206878105757264492625226;

        if (difference > 0 && difference <= 18) {
            if (baseTokenDecimals > quoteTokenDecimals) {
                adjustedSqrtRatioX96 = uint256(sqrtRatioX96) * (10 ** (difference / 2));
                if (difference % 2 == 1) {
                    adjustedSqrtRatioX96 = FullMath.mulDiv(adjustedSqrtRatioX96, sqrt10X128, 1 << 128);
                }
            } else {
                adjustedSqrtRatioX96 = uint256(sqrtRatioX96) / (10 ** (difference / 2));
                if (difference % 2 == 1) {
                    adjustedSqrtRatioX96 = FullMath.mulDiv(adjustedSqrtRatioX96, 1 << 128, sqrt10X128);
                }
            }
        } else {
            adjustedSqrtRatioX96 = uint256(sqrtRatioX96);
        }
    }

    function generateDecimalString(DecimalStringParams memory params) internal pure returns (string memory) {
        bytes memory buffer = new bytes(params.bufferLength);
        if (params.isPercent) {
            buffer[buffer.length - 1] = '%';
        }
        if (params.isLessThanOne) {
            buffer[0] = '0';
            buffer[1] = '.';
        }

        // add leading/trailing 0's
        for (uint256 zerosCursor = params.zerosStartIndex; zerosCursor < params.zerosEndIndex + 1; zerosCursor++) {
            buffer[zerosCursor] = bytes1(uint8(48));
        }
        // add sigfigs
        while (params.sigfigs > 0) {
            // insere o ponto decimal
            if (params.decimalIndex > 0 && params.sigfigIndex == params.decimalIndex) {
                buffer[params.sigfigIndex] = '.';
                if (params.sigfigIndex == 0) break;
                unchecked { --params.sigfigIndex; }
            }

            // insere o dígito
            buffer[params.sigfigIndex] = bytes1(uint8(48 + (params.sigfigs % 10)));
            if (params.sigfigIndex == 0) break;              // impede underflow
            unchecked { --params.sigfigIndex; }

            params.sigfigs /= 10;
        }
        return string(buffer);
    }

    function sigfigsRounded(uint256 value, uint8 digits) private pure returns (uint256, bool) {
        bool extraDigit;
        if (digits > 5) {
            value = value / (10 ** (digits - 5));
        }
        bool roundUp = value % 10 > 4;
        value = value / 10;
        if (roundUp) {
            value = value + 1;
        }
        // 99999 -> 100000 gives an extra sigfig
        if (value == 100000) {
            value = value / 10;
            extraDigit = true;
        }
        return (value, extraDigit);
    }

    /**
     * @notice Converts a sqrt price (Q64.96) to a human-readable decimal string.
     * @dev The returned value has 5 significant figures, handling sub-1 prices and rounding.
     * @param sqrtRatioX96 The sqrt price encoded as Q64.96.
     * @param baseTokenDecimals Number of decimals of the base token.
     * @param quoteTokenDecimals Number of decimals of the quote token.
     * @return priceString String representation of the price with precision.
     */
    function fixedPointToDecimalString(
        uint160 sqrtRatioX96,
        uint8 baseTokenDecimals,
        uint8 quoteTokenDecimals
    ) internal pure returns (string memory priceString) {
        uint256 adjustedSqrtRatioX96 = adjustForDecimalPrecision(sqrtRatioX96, baseTokenDecimals, quoteTokenDecimals);
        uint256 value = FullMath.mulDiv(adjustedSqrtRatioX96, adjustedSqrtRatioX96, 1 << 64);

        bool priceBelow1 = adjustedSqrtRatioX96 < 2**96;
        if (priceBelow1) {
            value = FullMath.mulDiv(value, 10**44, 1 << 128);
        } else {
            value = FullMath.mulDiv(value, 10**5, 1 << 128);
        }

        uint256 temp = value;
        uint8 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        digits = digits - 1;

        (uint256 sigfigs, bool extraDigit) = sigfigsRounded(value, digits);
        if (extraDigit) {
            digits++;
        }

        DecimalStringParams memory params;

        if (priceBelow1) {
            params.bufferLength = uint8(7 + (43 - digits));
            params.zerosStartIndex = 2;
            params.zerosEndIndex = uint8(43 - digits + 1);
            params.sigfigIndex = uint8(params.bufferLength - 1);
        } else if (digits >= 9) {
            params.bufferLength = uint8(digits - 4);
            params.zerosStartIndex = 5;
            params.zerosEndIndex = uint8(params.bufferLength - 1);
            params.sigfigIndex = 4;
        } else {
            params.bufferLength = 6;
            params.sigfigIndex = 5;
            params.decimalIndex = uint8(digits - 5 + 1);
        }

        params.sigfigs = sigfigs;
        params.isLessThanOne = priceBelow1;
        params.isPercent = false;

        return generateDecimalString(params);
    }
}
