// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {PoolTicksCounter} from "@evx-periphery/libraries/PoolTicksCounter.sol";
import {IEvxPool}     from "@evx-core/interfaces/IEvxPool.sol";


contract MockPool {
    int24 public immutable spacing;
    mapping(int16 => uint256) internal bitmaps;

    constructor(int24 _spacing) {
        spacing = _spacing;
    }

    /* ---------- getters with the exact signature used by the library -------- */

    function tickSpacing() external view returns (int24) {
        return spacing;
    }

    function tickBitmap(int16 wordPos) external view returns (uint256) {
        return bitmaps[wordPos];
    }

    /* ----------------------------- test helper ------------------------------ */

    /// @dev Sets the `wordPos` bitmap directly (ORs on top of the existing value).
    function setBit(int24 tick) external {
        int24 idx      = tick / spacing;        // tick index (multiple of spacing)
        int16 wordPos  = int16(idx >> 8);       // /256
        uint8 bitPos   = uint8(uint256(uint24(idx)) & 0xFF);
        bitmaps[wordPos] |= (uint256(1) << bitPos);
    }
}

contract PoolTicksCounterTest is Test {
    using PoolTicksCounter for IEvxPool;

    int24 internal constant SPACING = 60;       // keeps math tiny
    MockPool internal pool;

    function setUp() public {
        pool = new MockPool(SPACING);
    }

    /**
     * @notice Upwards swap from 0 to 120 with no initialized ticks in-between
     *         should return 0.
     */
    function testCountNone() external view {
        uint32 crossed = IEvxPool(address(pool))
            .countInitializedTicksCrossed(0, 120);
        assertEq(crossed, 0, "expected zero crossings");
    }

    /**
     * Path: 0  →  120;  initialized tick at 60.
     * We expect exactly 1 crossing.
     */
    function testCountMiddleTickUpwards() external {
        pool.setBit(60); // index 1
        uint32 crossed = IEvxPool(address(pool))
            .countInitializedTicksCrossed(0, 120);
        assertEq(crossed, 1, "should count middle tick only");
    }

    /**
     * Path: 0  →  120;  only tickAfter (120) is initialized.
     * Upwards swaps should count tickAfter, so result = 1.
     */
    function testCountTickAfterUpwards() external {
        pool.setBit(120); // index 2
        uint32 crossed = IEvxPool(address(pool))
            .countInitializedTicksCrossed(0, 120);
        assertEq(crossed, 1, "tickAfter should be counted upwards");
    }

    /**
     * Path: 120  →  0;  tickAfter (0) is initialized.
     * Downwards swaps must *exclude* tickAfter, so result = 0.
     */
    function testCountTickAfterDownwards() external {
        pool.setBit(0); // index 0
        uint32 crossed = IEvxPool(address(pool))
            .countInitializedTicksCrossed(120, 0);
        assertEq(crossed, 0, "tickAfter excluded on downward swap");
    }

    /* ---------------------------------------------------------------------- */
    /*              5. Crossing two words in the bitmap (upwards)             */
    /* ---------------------------------------------------------------------- */

    /**
     * tickBefore  = 0   (index 0, word 0)
     * tickAfter   = 300 (index 5 in word 1)
     * We initialise:
     *   - tick 60   (index 1, word 0)
     *   - tick 280  (index 24 in word 1)
     * Should count both → result = 2.
     */
    function testCountAcrossWords() external {
        pool.setBit(60);   // word 0, bit 1
        pool.setBit(280);  // word 1, bit 24

        uint32 crossed = IEvxPool(address(pool))
            .countInitializedTicksCrossed(0, 300);
        assertEq(crossed, 2, "cross-word count mismatch");
    }
}
