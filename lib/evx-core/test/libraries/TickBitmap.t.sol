// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-core/libraries/TickBitmap.sol";

contract TickBitmapHarness {
    using TickBitmap for mapping(int16 => uint256);
    mapping(int16 => uint256) public bitmap;

    /// @notice Flip the bit at the given tick with specified spacing
    function flip(int24 tick, int24 tickSpacing) external {
        bitmap.flipTick(tick, tickSpacing);
    }

    /// @notice Find next initialized tick within one word
    function nextWithinOneWord(
        int24 tick,
        int24 tickSpacing,
        bool lte
    ) external view returns (int24 next, bool initialized) {
        return bitmap.nextInitializedTickWithinOneWord(tick, tickSpacing, lte);
    }
}

/// @title TickBitmap Library Test Suite
/// @notice Unit tests for TickBitmap: flipping ticks and searching initialized bits
contract TickBitmapTest is Test {
    TickBitmapHarness harness;

    function setUp() public {
        harness = new TickBitmapHarness();
    }

    /// @notice flipTick should revert if tick is not spaced correctly
    function testFlipUnspacedReverts() public {
        vm.expectRevert(bytes("TickBitmap: unspaced tick"));
        harness.flip(5, 3); // 5 % 3 != 0
    }

    /// @notice flipTick toggles the bit and next finds it for lte search
        /// @notice flipTick toggles the bit and next finds it for lte search
    function testFlipAndNextLteExact() public {
        int24 tick = 10;
        int24 spacing = 1;
        // Initially no bits set => next should return 0
        (int24 next0, bool init0) = harness.nextWithinOneWord(tick, spacing, true);
        assertFalse(init0);
        assertEq(next0, int24(0), "Should return zero when no bits initialized");

        // Flip on
        harness.flip(tick, spacing);
        (int24 next1, bool init1) = harness.nextWithinOneWord(tick, spacing, true);
        assertTrue(init1);
        assertEq(next1, tick, "Should find flipped tick");

        // Flip off
        harness.flip(tick, spacing);
        (int24 next2, bool init2) = harness.nextWithinOneWord(tick, spacing, true);
        assertFalse(init2);
        assertEq(next2, int24(0), "Should return zero after flip off");
    }

    /// @notice nextInitializedTickWithinOneWord should find highest set bit <= tick
    function testNextLteMultiple() public {
        int24 spacing = 5;
        // Flip ticks 5, 10, 20
        harness.flip(5, spacing);
        harness.flip(10, spacing);
        harness.flip(20, spacing);
        // Search at tick 25 lte => should find 20
        (int24 next, bool init) = harness.nextWithinOneWord(25, spacing, true);
        assertTrue(init);
        assertEq(next, 20);
    }

    /// @notice nextInitializedTickWithinOneWord should find lowest set bit >= tick
        /// @notice nextInitializedTickWithinOneWord should find lowest set bit >= tick
    function testNextGteMultiple() public {
        int24 spacing = 5;
        // Flip ticks 10, 20
        harness.flip(10, spacing);
        harness.flip(20, spacing);
        // Search right from tick 5 => next should be 10
        (int24 next, bool init) = harness.nextWithinOneWord(5, spacing, false);
        assertTrue(init);
        assertEq(next, int24(10));

        // Search right from just before 20 => next should be 20
        (int24 next3, bool init3) = harness.nextWithinOneWord(19, spacing, false);
        assertTrue(init3);
        assertEq(next3, int24(20));
    }
}
