// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@evx-core/interfaces/IEvxPool.sol';

/**
 * @title PoolTicksCounter
 * @notice Provides a utility to count the number of initialized ticks crossed between two tick values in a Evx pool.
 * @dev This is useful for estimating gas costs and behaviors in swaps that traverse tick ranges.
 */
library PoolTicksCounter {
    /**
     * @notice Counts the number of initialized ticks crossed between two ticks.
     * @dev If a tick is initialized, whether it's included depends on swap direction:
     *      - Swapping up (tickAfter > tickBefore): count tickAfter, skip tickBefore.
     *      - Swapping down (tickAfter < tickBefore): count tickBefore, skip tickAfter.
     * @param self The Evx pool to read tick data from.
     * @param tickBefore The starting tick (before swap).
     * @param tickAfter The ending tick (after swap).
     * @return initializedTicksCrossed The number of initialized ticks crossed.
     */
    function countInitializedTicksCrossed(
        IEvxPool self,
        int24 tickBefore,
        int24 tickAfter
    ) internal view returns (uint32 initializedTicksCrossed) {
        int16 wordPosLower;
        int16 wordPosHigher;
        uint8 bitPosLower;
        uint8 bitPosHigher;
        bool tickBeforeInitialized;
        bool tickAfterInitialized;

        {
            int24 spacing = self.tickSpacing();

            // Get the key and offset in the tick bitmap of the active tick before and after the swap.
            int16 wordPos = int16((tickBefore / spacing) >> 8);
            uint8 bitPos = uint8(uint256(int256(tickBefore) / int256(spacing)) % 256);

            int16 wordPosAfter = int16((tickAfter / spacing) >> 8);
            uint8 bitPosAfter = uint8(uint256(int256(tickAfter) / int256(spacing)) % 256);

            // In the case where tickAfter is initialized, we only want to count it if we are swapping downwards.
            // If the initializable tick after the swap is initialized, our original tickAfter is a
            // multiple of tick spacing, and we are swapping downwards we know that tickAfter is initialized
            // and we shouldn't count it.
            tickAfterInitialized =
                ((self.tickBitmap(wordPosAfter) & (1 << bitPosAfter)) > 0) &&
                ((tickAfter % self.tickSpacing()) == 0) &&
                (tickBefore > tickAfter);

            // In the case where tickBefore is initialized, we only want to count it if we are swapping upwards.
            // Use the same logic as above to decide whether we should count tickBefore or not.
            tickBeforeInitialized =
                ((self.tickBitmap(wordPos) & (1 << bitPos)) > 0) &&
                ((tickBefore % self.tickSpacing()) == 0) &&
                (tickBefore < tickAfter);

            if (wordPos < wordPosAfter || (wordPos == wordPosAfter && bitPos <= bitPosAfter)) {
                wordPosLower = wordPos;
                bitPosLower = bitPos;
                wordPosHigher = wordPosAfter;
                bitPosHigher = bitPosAfter;
            } else {
                wordPosLower = wordPosAfter;
                bitPosLower = bitPosAfter;
                wordPosHigher = wordPos;
                bitPosHigher = bitPos;
            }
        }

        // Count the number of initialized ticks crossed by iterating through the tick bitmap.
        // Our first mask should include the lower tick and everything to its left.
        uint256 mask = type(uint256).max << bitPosLower;
        while (wordPosLower <= wordPosHigher) {
            
            // If we're on the final tick bitmap page, ensure we only count up to our ending tick.
            if (wordPosLower == wordPosHigher) {
                mask = mask & (type(uint256).max >> (255 - bitPosHigher));
            }

            uint256 masked = self.tickBitmap(wordPosLower) & mask;
            initializedTicksCrossed += countOneBits(masked);
            wordPosLower++;
            // Reset our mask so we consider all bits on the next iteration.
            mask = type(uint256).max;
        }

        if (tickAfterInitialized) {
            initializedTicksCrossed -= 1;
        }

        if (tickBeforeInitialized) {
            initializedTicksCrossed -= 1;
        }

        return initializedTicksCrossed;
    }

    /**
     * @notice Counts the number of 1 bits in a uint256.
     * @dev Uses Brian Kernighan's algorithm to count bits set to 1.
     * @param x The number to count bits in.
     * @return bits The number of 1 bits.
     */
    function countOneBits(uint256 x) private pure returns (uint16 bits) {
        while (x != 0) {
            bits++;
            x &= (x - 1);
        }
    }
}
