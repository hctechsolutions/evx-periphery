// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-core/libraries/Tick.sol";
import "@evx-core/libraries/TickMath.sol";
import "@evx-core/libraries/LiquidityMath.sol";

contract TickHarness {
    using Tick for mapping(int24 => Tick.Info);

    mapping(int24 => Tick.Info) public ticks;

    function callTickSpacingToMaxLiquidity(int24 spacing) external pure returns (uint128) {
        return Tick.tickSpacingToMaxLiquidityPerTick(spacing);
    }

    function callGetFeeGrowthInside(
        int24 lower,
        int24 upper,
        int24 current,
        uint256 global0,
        uint256 global1
    ) external view returns (uint256 inside0, uint256 inside1) {
        return ticks.getFeeGrowthInside(lower, upper, current, global0, global1);
    }

    function callUpdate(
        int24 tick,
        int24 current,
        int128 delta,
        uint256 global0,
        uint256 global1,
        uint160 secondsPerLiquidityX128,
        int56 tickCumul,
        uint32 time,
        bool upper,
        uint128 maxLiq
    ) external returns (bool flipped) {
        return ticks.update(tick, current, delta, global0, global1, secondsPerLiquidityX128, tickCumul, time, upper, maxLiq);
    }

    function callClear(int24 tick) external {
        ticks.clear(tick);
    }

    function callCross(
        int24 tick,
        uint256 global0,
        uint256 global1,
        uint160 secondsPerLiquidityX128,
        int56 tickCumul,
        uint32 time
    ) external returns (int128 liquidityNet) {
        return ticks.cross(tick, global0, global1, secondsPerLiquidityX128, tickCumul, time);
    }

    // Helpers for testing
    function setFeeGrowthOutside(int24 tick, uint256 f0, uint256 f1) external {
        ticks[tick].feeGrowthOutside0X128 = f0;
        ticks[tick].feeGrowthOutside1X128 = f1;
    }

    function getInfo(int24 tick) external view returns (
        uint128 liquidityGross,
        int128 liquidityNet,
        uint256 feeGrowthOutside0X128,
        uint256 feeGrowthOutside1X128,
        int56 tickCumulativeOutside,
        uint160 secondsPerLiquidityOutsideX128,
        uint32 secondsOutside,
        bool initialized
    ) {
        Tick.Info storage info = ticks[tick];
        return (
            info.liquidityGross,
            info.liquidityNet,
            info.feeGrowthOutside0X128,
            info.feeGrowthOutside1X128,
            info.tickCumulativeOutside,
            info.secondsPerLiquidityOutsideX128,
            info.secondsOutside,
            info.initialized
        );
    }
}

contract TickTest is Test {
    TickHarness harness;

    function setUp() public {
        harness = new TickHarness();
    }

    /// @notice tickSpacingToMaxLiquidityPerTick should divide max uint128 by correct number of ticks
        /// @notice tickSpacingToMaxLiquidityPerTick should return max when spacing covers entire range
    function testTickSpacingToMaxLiquidity() public view {
        int24 spacing = TickMath.MAX_TICK - TickMath.MIN_TICK; // full range
        uint128 maxLiq = harness.callTickSpacingToMaxLiquidity(spacing);
        // Only one usable tick, so max liquidity per tick is full uint128
        assertEq(maxLiq, type(uint128).max);
    }

    /// @notice getFeeGrowthInside for current above upper
    function testGetFeeGrowthInsideAbove() public {
        int24 lower = 0;
        int24 upper = 10;
        int24 current = 15;
        uint256 global0 = 100;
        uint256 global1 = 200;
        // set outside values
        harness.setFeeGrowthOutside(lower, 10, 20);
        harness.setFeeGrowthOutside(upper, 30, 40);
        (uint256 inside0, uint256 inside1) = harness.callGetFeeGrowthInside(lower, upper, current, global0, global1);
        // feeGrowthBelow0 = 10, feeGrowthAbove0 = global0 - 30 = 70, inside0 = 100 -10 -70 =20
        assertEq(inside0, 20);
        // feeGrowthBelow1 =20, feeGrowthAbove1 =200 -40 =160, inside1 =200 -20 -160 =20
        assertEq(inside1, 20);
    }

    /// @notice getFeeGrowthInside for current below lower
    function testGetFeeGrowthInsideBelow() public {
        int24 lower = 0;
        int24 upper = 10;
        int24 current = -5;
        uint256 global0 = 100;
        uint256 global1 = 200;
        harness.setFeeGrowthOutside(lower, 10, 20);
        harness.setFeeGrowthOutside(upper, 5, 15);
        (uint256 inside0, uint256 inside1) = harness.callGetFeeGrowthInside(lower, upper, current, global0, global1);
        // feeGrowthBelow0 =90, feeGrowthAbove0 =5, inside0=100 -90 -5=5
        assertEq(inside0, 5);
        // feeGrowthBelow1=180, feeGrowthAbove1=15, inside1=200 -180 -15=5
        assertEq(inside1, 5);
    }

    /// @notice update initializes tick and flips when going from zero to non-zero
    function testUpdateInitializeAndFlip() public {
        int24 tick = 5;
        int24 current = 0;
        int128 delta = int128(100);
        uint128 maxLiq = 200;
        bool flipped = harness.callUpdate(tick, current, delta, 0, 0, 0, 0, uint32(block.timestamp), false, maxLiq);
        assertTrue(flipped, "Should flip on init");
        // verify storage via getter
        (uint128 lg, , , , , , , bool init) = harness.getInfo(tick);
        assertEq(lg, 100);
        assertTrue(init);
    }

    /// @notice clear resets tick info to default
    function testClear() public {
        int24 tick = 7;
        harness.callUpdate(tick, 0, int128(50), 0, 0, 0, 0, uint32(block.timestamp), true, 100);
        harness.callClear(tick);
        (uint128 lg, , , , , , , bool init) = harness.getInfo(tick);
        assertEq(lg, 0);
        assertFalse(init);
    }

        /// @notice cross flips fee growth and returns liquidityNet
    function testCross() public {
        int24 tick = 3;
        // initialize tick; since tick>current, outside fields stay zero
        harness.callUpdate(tick, 0, int128(200), 10, 20, 30, 40, uint32(100), true, 500);
        int128 net = harness.callCross(tick, 15, 25, 35, 45, 150);
        assertEq(net, -int128(200), "liquidityNet mismatch");
        (uint128 lg,
            int128 ln,
            uint256 f0out,
            uint256 f1out,
            int56 tcOut,
            uint160 splOut,
            uint32 secOut,
            bool init) = harness.getInfo(tick);
        // feeGrowthOutside0X128 = global0 - previousOutside0 = 15 - 0
        assertEq(f0out, 15, "feeGrowthOutside0X128 mismatch");
        // secondsPerLiquidityOutsideX128 = globalSecondsPerLiquidity - previousOutside = 35 - 0
        assertEq(splOut, 35, "secondsPerLiquidityOutsideX128 mismatch");
        // secondsOutside = time - previousSecondsOutside = 150 - 0
        assertEq(secOut, 150, "secondsOutside mismatch");
        assertTrue(init, "initialized flag should remain true");
    }
}
