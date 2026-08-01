// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PositionKeyTest
 * @notice Unit tests for the PositionKey library.
 */
import "forge-std/Test.sol";
import {PositionKey} from "@evx-periphery/libraries/PositionKey.sol";

contract PositionKeyWrapper {
    function key(
        address owner,
        int24 lower,
        int24 upper
    ) external pure returns (bytes32) {
        return PositionKey.compute(owner, lower, upper);
    }
}

contract PositionKeyTest is Test {
    PositionKeyWrapper internal wrap;

    address internal constant ALICE = 0x1111111111111111111111111111111111111111;
    address internal constant BOB   = 0x2222222222222222222222222222222222222222;

    int24  internal constant LOWER  = -600;
    int24  internal constant UPPER  =  600;

    function setUp() public {
        wrap = new PositionKeyWrapper();
    }

    /// Calling twice with identical parameters must give the same hash.
    function testDeterministic() external view {
        bytes32 k1 = wrap.key(ALICE, LOWER, UPPER);
        bytes32 k2 = wrap.key(ALICE, LOWER, UPPER);
        assertEq(k1, k2, "compute not deterministic");
    }

    /// Different owner => different key.
    function testDifferentOwner() external view {
        bytes32 aliceKey = wrap.key(ALICE, LOWER, UPPER);
        bytes32 bobKey   = wrap.key(BOB,   LOWER, UPPER);
        assertTrue(aliceKey != bobKey, "owner should change key");
    }

    /// Swapping tickLower / tickUpper must change the hash.
    function testOrderMatters() external view {
        bytes32 kNormal = wrap.key(ALICE, LOWER, UPPER);
        bytes32 kFlipped= wrap.key(ALICE, UPPER, LOWER);
        assertTrue(kNormal != kFlipped, "tick order should matter");
    }

    /// Changing either tick bound changes the key (uniqueness across positions).
    function testDifferentTicks() external view {
        bytes32 base   = wrap.key(ALICE, LOWER, UPPER);
        bytes32 shifted= wrap.key(ALICE, LOWER + 60, UPPER);
        assertTrue(base != shifted, "tick change should alter key");
    }
}
