// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BitMath.sol";

/**
 * @title TickBitmap
 * @notice Packed tick state mapping for determining initialization status of ticks.
 * @dev Allows efficient tracking of tick initialization using bitmaps.
 */
library TickBitmap {
    /**
     * @notice Computes the word and bit position of a given tick in the bitmap.
     * @dev Used to map a tick index to a specific bit in a 256-bit storage word.
     * @param tick The tick index to locate.
     * @return wordPos The int16 word position in the bitmap.
     * @return bitPos The uint8 bit position within the word.
     */
    function position(int24 tick) private pure returns (int16 wordPos, uint8 bitPos) {
        wordPos = int16(tick >> 8);
        bitPos = uint8(uint24(tick));
    }

    /**
     * @notice Toggles the initialized state of a given tick.
     * @dev Uses XOR to flip the bit representing the tick's state.
     * @param self The mapping representing the bitmap.
     * @param tick The tick index to flip.
     * @param tickSpacing The spacing between initialized ticks (must divide tick).
     */
    function flipTick(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing
    ) internal {
        require(tick % tickSpacing == 0, "TickBitmap: unspaced tick");
        (int16 wordPos, uint8 bitPos) = position(tick / tickSpacing);
        self[wordPos] ^= (uint256(1) << bitPos);
    }

    /**
     * @notice Finds the next initialized tick in the same word.
     * @dev If `lte` is true, searches left (lower ticks); otherwise, searches right (higher ticks).
     * @param self The mapping representing the bitmap.
     * @param tick The current tick to search from.
     * @param tickSpacing The spacing between initialized ticks.
     * @param lte Whether to search toward lower ticks (<=).
     * @return next The next initialized tick index.
     * @return initialized True if an initialized tick was found.
     */
    function nextInitializedTickWithinOneWord(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing,
        bool  lte
    ) internal view returns (int24 next, bool initialized) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--; // floor toward −∞

        if (lte) {
            (int16 wordPos, uint8 bitPos) = position(compressed);
            uint256 mask   = (uint256(1) << bitPos) + ((uint256(1) << bitPos) - 1);
            uint256 masked = self[wordPos] & mask;

            initialized = masked != 0;
            if (initialized) {
                uint256 msb = BitMath.mostSignificantBit(masked);
                int256  diff = int256(uint256(bitPos)) - int256(msb);
                next = (compressed - int24(diff)) * tickSpacing;
            } else {
                int256 diff = int256(uint256(bitPos));
                next = (compressed - int24(diff)) * tickSpacing;
            }
        } else {
            (int16 wordPos, uint8 bitPos) = position(compressed + 1);
            uint256 mask   = ~((uint256(1) << bitPos) - 1);
            uint256 masked = self[wordPos] & mask;

            initialized = masked != 0;
            if (initialized) {
                uint256 lsb = BitMath.leastSignificantBit(masked);
                int256  diff = int256(lsb) - int256(uint256(bitPos));
                next = (compressed + 1 + int24(diff)) * tickSpacing;
            } else {
                int256 diff = int256(uint256(type(uint8).max)) - int256(uint256(bitPos));
                next = (compressed + 1 + int24(diff)) * tickSpacing;
            }
        }
    }
}
