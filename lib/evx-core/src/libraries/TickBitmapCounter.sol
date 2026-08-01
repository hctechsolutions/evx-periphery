// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title TickBitmapCounter
 * @notice Counts initialized ticks crossed between two tick values using a pool's tick bitmap.
 * @dev Used by EvxPool to provide countInitializedTicksCrossed for swap callbacks.
 *      Refactored to avoid "stack too deep" by using helper functions.
 */
library TickBitmapCounter {
    function countInitializedTicksCrossed(
        mapping(int16 => uint256) storage self,
        int24 tickSpacing,
        int24 tickBefore,
        int24 tickAfter
    ) internal view returns (uint32 initializedTicksCrossed) {
        (int16 wordPosLower, uint8 bitPosLower, int16 wordPosHigher, uint8 bitPosHigher) =
            getWordBitRange(tickSpacing, tickBefore, tickAfter);

        bool tickAfterInit = isTickInitializedInRange(self, tickSpacing, tickBefore, tickAfter, true);
        bool tickBeforeInit = isTickInitializedInRange(self, tickSpacing, tickBefore, tickAfter, false);

        initializedTicksCrossed = countBitsInRange(self, wordPosLower, bitPosLower, wordPosHigher, bitPosHigher);

        if (tickAfterInit) initializedTicksCrossed -= 1;
        if (tickBeforeInit) initializedTicksCrossed -= 1;
    }

    function getWordBitRange(
        int24 tickSpacing,
        int24 tickBefore,
        int24 tickAfter
    ) private pure returns (int16 wordPosLower, uint8 bitPosLower, int16 wordPosHigher, uint8 bitPosHigher) {
        int16 wordPos = int16((tickBefore / tickSpacing) >> 8);
        uint8 bitPos = uint8(uint256(int256(tickBefore) / int256(tickSpacing)) % 256);
        int16 wordPosAfter = int16((tickAfter / tickSpacing) >> 8);
        uint8 bitPosAfter = uint8(uint256(int256(tickAfter) / int256(tickSpacing)) % 256);

        if (wordPos < wordPosAfter || (wordPos == wordPosAfter && bitPos <= bitPosAfter)) {
            return (wordPos, bitPos, wordPosAfter, bitPosAfter);
        }
        return (wordPosAfter, bitPosAfter, wordPos, bitPos);
    }

    function isTickInitializedInRange(
        mapping(int16 => uint256) storage self,
        int24 tickSpacing,
        int24 tickBefore,
        int24 tickAfter,
        bool useTickAfter
    ) private view returns (bool) {
        int24 tick = useTickAfter ? tickAfter : tickBefore;
        int16 wordPos = int16((tick / tickSpacing) >> 8);
        uint8 bitPos = uint8(uint256(int256(tick) / int256(tickSpacing)) % 256);
        if ((tick % tickSpacing) != 0) return false;
        if ((self[wordPos] & (1 << bitPos)) == 0) return false;
        if (useTickAfter) return tickBefore > tickAfter;
        return tickBefore < tickAfter;
    }

    function countBitsInRange(
        mapping(int16 => uint256) storage self,
        int16 wordPosLower,
        uint8 bitPosLower,
        int16 wordPosHigher,
        uint8 bitPosHigher
    ) private view returns (uint32 n) {
        uint256 mask = type(uint256).max << bitPosLower;
        while (wordPosLower <= wordPosHigher) {
            if (wordPosLower == wordPosHigher) {
                mask = mask & (type(uint256).max >> (255 - bitPosHigher));
            }
            uint256 masked = self[wordPosLower] & mask;
            n += uint32(countOneBits(masked));
            wordPosLower++;
            mask = type(uint256).max;
        }
    }

    function countOneBits(uint256 x) private pure returns (uint16 bits) {
        while (x != 0) {
            bits++;
            x &= (x - 1);
        }
    }
}
