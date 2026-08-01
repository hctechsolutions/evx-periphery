// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LiquidityMath
 * @notice Math library for safely adjusting liquidity values.
 * @dev Provides safe arithmetic for applying signed deltas to unsigned liquidity values.
 */
library LiquidityMath {
    /**
     * @notice Applies a signed liquidity delta to an existing liquidity value.
     * @dev Reverts if the resulting liquidity would underflow or overflow a uint128.
     * @param x The current liquidity before applying the delta.
     * @param y The signed delta to apply. Can be positive (increase) or negative (decrease).
     * @return z The resulting liquidity after applying the delta.
     */
    function addDelta(uint128 x, int128 y) internal pure returns (uint128 z) {
        if (y < 0) {
             unchecked {
                 z = x - uint128(-y);
             }
             require(z < x, "LS"); // underflow if delta > x
         } else {
             unchecked {
                 z = x + uint128(y);
             }
             require(z >= x, "LA"); // overflow if result < x
         }
    }
}
