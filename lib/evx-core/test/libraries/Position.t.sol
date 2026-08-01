// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-core/libraries/Position.sol";
import "@evx-core/libraries/LiquidityMath.sol";
import "@evx-core/libraries/FullMath.sol";
import "@evx-core/libraries/FixedPoint128.sol";

/// @notice Harness to test Position library
contract PositionHarness {
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;
    using Position for mapping(bytes32 => Position.Info);

    mapping(bytes32 => Position.Info) public positions;

    /// @notice Update a position identified by owner & tick bounds
    function updatePosition(
        address owner,
        int24 tickLower,
        int24 tickUpper,
        int128 liquidityDelta,
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) external {
        Position.Info storage pos = positions.get(owner, tickLower, tickUpper);
        pos.update(liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128);
    }

    /// @notice Get position fields
    function getPosition(
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) external view returns (
        uint128 liquidity,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    ) {
        Position.Info storage pos = positions.get(owner, tickLower, tickUpper);
        return (
            pos.liquidity,
            pos.feeGrowthInside0LastX128,
            pos.feeGrowthInside1LastX128,
            pos.tokensOwed0,
            pos.tokensOwed1
        );
    }
}

/// @title Position Library Test Suite
contract PositionTest is Test {
    PositionHarness harness;
    address owner;
    int24 lower;
    int24 upper;

    function setUp() public {
        harness = new PositionHarness();
        owner = address(this);
        lower = -10;
        upper = 10;
    }

    /// @notice Zero delta on new position should revert NP
    function testUpdateZeroDeltaReverts() public {
        vm.expectRevert(bytes("NP"));
        harness.updatePosition(owner, lower, upper, 0, 0, 0);
    }

    /// @notice Adding liquidity updates liquidity and snapshots without fees
    function testUpdateAddLiquidity() public {
        harness.updatePosition(owner, lower, upper, int128(1000), 0, 0);
        (
            uint128 liq,
            uint256 f0last,
            uint256 f1last,
            uint128 owed0,
            uint128 owed1
        ) = harness.getPosition(owner, lower, upper);
        assertEq(liq, 1000, "Liquidity should be 1000");
        assertEq(f0last, 0, "feeGrowthInside0LastX128 should be 0");
        assertEq(f1last, 0, "feeGrowthInside1LastX128 should be 0");
        assertEq(owed0, 0, "tokensOwed0 should be 0");
        assertEq(owed1, 0, "tokensOwed1 should be 0");
    }

    /// @notice Fee accrual with zero delta credits tokens owed and updates snapshots
    function testFeeAccrualOnZeroDelta() public {
        // initial add
        harness.updatePosition(owner, lower, upper, int128(500), 0, 0);
        uint256 fee0 = FixedPoint128.Q128 * 20; // equivalent to 20 units per liquidity
        uint256 fee1 = FixedPoint128.Q128 * 10;
        // accrue fees with zero liquidity delta
        harness.updatePosition(owner, lower, upper, 0, fee0, fee1);
        (
            uint128 liq,
            uint256 f0last,
            uint256 f1last,
            uint128 owed0,
            uint128 owed1
        ) = harness.getPosition(owner, lower, upper);
        // liquidity unchanged
        assertEq(liq, 500);
        // snapshots updated
        assertEq(f0last, fee0);
        assertEq(f1last, fee1);
        // tokens owed = floor((feeGrowthInsideX128 diff * liquidity) / Q128)
        assertEq(owed0, 500 * 20);
        assertEq(owed1, 500 * 10);
    }

    /// @notice Subsequent fee accrual accumulates additional tokens owed
    function testMultipleFeeAccruals() public {
        // initial add and first accrual
        harness.updatePosition(owner, lower, upper, int128(200), 0, 0);
        uint256 fee0a = FixedPoint128.Q128 * 5;
        harness.updatePosition(owner, lower, upper, 0, fee0a, 0);
        // second accrual
        uint256 fee0b = FixedPoint128.Q128 * 15;
        harness.updatePosition(owner, lower, upper, 0, fee0b, 0);
        (, , , uint128 owed0, ) = harness.getPosition(owner, lower, upper);
        // owed0 = 200*5 + 200*(15-5) = 200*15 = 3000
        assertEq(owed0, 3000, "Cumulative tokens owed mismatch");
    }

    /// @notice Removing liquidity decreases liquidity correctly and accrues fees
    function testRemoveLiquidityAndFees() public {
        // add liquidity
        harness.updatePosition(owner, lower, upper, int128(1000), 0, 0);
        // accrue some fees
        uint256 fee0 = FixedPoint128.Q128 * 2;
        harness.updatePosition(owner, lower, upper, 0, fee0, 0);
        // remove half liquidity with new fees
        uint256 fee0b = FixedPoint128.Q128 * 4;
        harness.updatePosition(owner, lower, upper, -int128(500), fee0b, 0);
        (uint128 liq, , , uint128 owed0, ) = harness.getPosition(owner, lower, upper);
        // new liquidity = 500
        assertEq(liq, 500, "Liquidity after removal should be 500");
        // tokens owed = 1000*2 + 1000*(4-2) = 2000 + 2000 = 4000
        assertEq(owed0, 4000, "Tokens owed after removal mismatch");
    }

    /// @notice Removing more liquidity than exists reverts LS
    function testUnderflowOnRemoveReverts() public {
        harness.updatePosition(owner, lower, upper, int128(100), 0, 0);
        vm.expectRevert(bytes("LS"));
        harness.updatePosition(owner, lower, upper, -int128(200), 0, 0);
    }
}
