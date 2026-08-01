// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-core/libraries/Oracle.sol";

contract OracleHarness {
    using Oracle for Oracle.Observation[65535];

    Oracle.Observation[65535] public obs;
    uint16 public cardinality;
    uint16 public cardinalityNext;
    uint16 public index;

    /// @notice Initialize oracle with first observation at time
    function init(uint32 time) external {
        (cardinality, cardinalityNext) = obs.initialize(time);
        index = 0;
    }

    /// @notice Grow observation capacity from current to next
    function grow(uint16 current, uint16 next) external returns (uint16) {
        cardinalityNext = obs.grow(current, next);
        return cardinalityNext;
    }

    /// @notice Write a new observation with given parameters
    function writeObs(uint32 time, int24 tick, uint128 liquidity) external {
        (index, cardinality) = obs.write(index, time, tick, liquidity, cardinality, cardinalityNext);
    }

    /// @notice Fetch single observation for given secondsAgo and state
    function observeSingleExternal(
        uint32 time,
        uint32 secondsAgo,
        int24 tick,
        uint128 liquidity
    ) external view returns (int56, uint160) {
        return obs.observeSingle(time, secondsAgo, tick, index, liquidity, cardinality);
    }

    /// @notice Fetch multiple observations for given secondsAgos
    function observeExternal(
        uint32 time,
        uint32[] memory secondsAgos,
        int24 tick,
        uint128 liquidity
    ) external view returns (int56[] memory, uint160[] memory) {
        return obs.observe(time, secondsAgos, tick, index, liquidity, cardinality);
    }
}

contract OracleTest is Test {
    OracleHarness harness;

    function setUp() public {
        harness = new OracleHarness();
    }

    /// @notice Should initialize with cardinality and capacity of 1 and zero accumulators
    function testInitialize() public {
        uint32 t0 = uint32(block.timestamp);
        harness.init(t0);
        assertEq(harness.cardinality(), 1);
        assertEq(harness.cardinalityNext(), 1);
        (int56 tickC, uint160 spl) = harness.observeSingleExternal(t0, 0, 0, 0);
        assertEq(tickC, 0);
        assertEq(spl, 0);
    }

    /// @notice Should grow capacity and pre-fill new slots
    function testGrow() public {
        harness.init(100);
        uint16 next = harness.grow(1, 3);
        assertEq(next, 3, "grow(1,3) should return 3");
    }

    /// @notice Writing with same timestamp should not change index or cardinality
    function testWriteSameBlockNoChange() public {
        harness.init(50);
        harness.writeObs(50, 10, 100);
        assertEq(harness.index(), 0);
        assertEq(harness.cardinality(), 1);
    }

    /// @notice Writing after grow should increment cardinality and index
    function testWriteIncrementsCardinality() public {
        harness.init(1000);
        harness.grow(1, 2);
        harness.writeObs(1001, 5, 200);
        assertEq(harness.index(), 1);
        assertEq(harness.cardinality(), 2);
        (int56 tickC, uint160 spl) = harness.observeSingleExternal(1001, 0, 5, 200);
        assertEq(tickC, 5);
        uint160 expectedSpl = uint160((uint160(1) << 128) / 200);
        assertEq(spl, expectedSpl);
    }

    /// @notice observeSingle should return transformed values for secondsAgo > 0
    function testObserveSingleDelta() public {
        harness.init(0);
        harness.grow(1, 2);
        harness.writeObs(10, 2, 100);
        // Query 5 seconds ago at time 15
        (int56 tickC, uint160 spl) = harness.observeSingleExternal(15, 5, 2, 100);
        // target =10 equals last observation
        assertEq(tickC, 2 * 10);
        uint160 expectedSpl = uint160((uint160(10) << 128) / 100);
        assertEq(spl, expectedSpl);
    }

    /// @notice observe should return arrays matching observeSingle for multiple offsets
    function testObserveMultiple() public {
        harness.init(0);
        harness.grow(1, 3);
        harness.writeObs(10, 1, 100);
        harness.writeObs(20, 2, 200);
        uint32[] memory agos = new uint32[](2);
        agos[0] = 0;
        agos[1] = 10;
        (int56[] memory ticks, uint160[] memory spls) = harness.observeExternal(20, agos, 2, 200);
        // latest at time 20
        assertEq(ticks[0], 30);
        uint160 spl0 = uint160((uint160(10) << 128) / 100 + (uint160(10) << 128) / 200);
        assertEq(spls[0], spl0);
        // 10 seconds ago equals first observation
        assertEq(ticks[1], 1 * 10);
        uint160 spl1 = uint160((uint160(10) << 128) / 100);
        assertEq(spls[1], spl1);
    }

    /// @notice observe should revert when cardinality is zero
    function testObserveRevertsWhenEmpty() public {
        uint32[] memory agos = new uint32[](1);
        agos[0] = 0;
        vm.expectRevert();
        harness.observeExternal(uint32(block.timestamp), agos, 0, 0);
    }
}
