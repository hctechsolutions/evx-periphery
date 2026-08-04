// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {EvxEmergencyPause} from "@evx-periphery/contracts/EvxEmergencyPause.sol";
import {IEvxEmergencyPause} from "@evx-periphery/interfaces/IEvxEmergencyPause.sol";
import {
    OnlyPauser,
    ZeroPauser,
    EnforcedPause,
    ExpectedPause,
    InvalidCriticalOp
} from "@evx-periphery/libraries/EmergencyPauseErrors.sol";

/**
 * @title EvxEmergencyPause Test Suite
 * @notice Foundry/Anvil PoC coverage for Story 5.8 (FR19 / NFR8 / NFR11)
 * @dev NFR8 note: these tests prove pause is confirmable in **one PoC block** under Anvil.
 *      Arbitrum &lt; 1 block is an integration/testnet property when that environment is
 *      exercised — do not treat Anvil mining alone as proof of NFR8 on Arbitrum.
 */
contract EvxEmergencyPauseTest is Test {
    EvxEmergencyPause private emergencyPause;

    address private constant PAUSER = address(0xBEEF);
    address private constant UNAUTHORIZED = address(0xDEAD);

    uint8 private constant OP_REBALANCE = 1;
    uint8 private constant OP_SET_DYNAMIC_FEE = 2;

    function setUp() public {
        emergencyPause = new EvxEmergencyPause(PAUSER);
    }

    function testConstructorRejectsZeroPauser() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroPauser.selector));
        new EvxEmergencyPause(address(0));
    }

    function testPauserIsImmutableGetter() public view {
        assertEq(emergencyPause.pauser(), PAUSER);
    }

    function testStartsUnpaused() public view {
        assertFalse(emergencyPause.paused());
        emergencyPause.requireNotPaused();
    }

    /**
     * @notice Authorized pause → paused==true in the same PoC block (NFR8 Anvil proof only)
     */
    function testAuthorizedPauseConfirmsInSameBlock() public {
        uint256 blockBefore = block.number;

        vm.prank(PAUSER);
        vm.expectEmit(true, false, false, true);
        emit IEvxEmergencyPause.Paused(PAUSER);
        emergencyPause.pause();

        assertTrue(emergencyPause.paused());
        assertEq(
            block.number,
            blockBefore,
            "PoC: pause confirmable in one Anvil block; Arbitrum NFR8 = when that env is exercised"
        );
    }

    function testAuthorizedUnpause() public {
        vm.prank(PAUSER);
        emergencyPause.pause();
        assertTrue(emergencyPause.paused());

        vm.prank(PAUSER);
        vm.expectEmit(true, false, false, true);
        emit IEvxEmergencyPause.Unpaused(PAUSER);
        emergencyPause.unpause();

        assertFalse(emergencyPause.paused());
        emergencyPause.requireNotPaused();
    }

    function testUnauthorizedPauseReverts() public {
        vm.prank(UNAUTHORIZED);
        vm.expectRevert(abi.encodeWithSelector(OnlyPauser.selector));
        emergencyPause.pause();
        assertFalse(emergencyPause.paused());
    }

    function testUnauthorizedUnpauseReverts() public {
        vm.prank(PAUSER);
        emergencyPause.pause();

        vm.prank(UNAUTHORIZED);
        vm.expectRevert(abi.encodeWithSelector(OnlyPauser.selector));
        emergencyPause.unpause();
        assertTrue(emergencyPause.paused());
    }

    function testPauseWhilePausedReverts() public {
        vm.startPrank(PAUSER);
        emergencyPause.pause();
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        emergencyPause.pause();
        vm.stopPrank();
    }

    function testUnpauseWhileNotPausedReverts() public {
        vm.prank(PAUSER);
        vm.expectRevert(abi.encodeWithSelector(ExpectedPause.selector));
        emergencyPause.unpause();
    }

    function testCriticalOpsSucceedWhenNotPaused() public view {
        emergencyPause.gateCriticalOp(OP_SET_DYNAMIC_FEE);
        emergencyPause.gateCriticalOp(OP_REBALANCE);
        emergencyPause.requireNotPaused();
    }

    function testCriticalOpsRevertWhilePaused() public {
        vm.prank(PAUSER);
        emergencyPause.pause();

        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        emergencyPause.gateCriticalOp(OP_SET_DYNAMIC_FEE);

        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        emergencyPause.gateCriticalOp(OP_REBALANCE);

        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        emergencyPause.requireNotPaused();
    }

    function testCriticalOpsSucceedAfterUnpause() public {
        vm.startPrank(PAUSER);
        emergencyPause.pause();
        emergencyPause.unpause();
        vm.stopPrank();

        emergencyPause.gateCriticalOp(OP_SET_DYNAMIC_FEE);
        emergencyPause.gateCriticalOp(OP_REBALANCE);
        emergencyPause.requireNotPaused();
    }

    function testInvalidCriticalOpReverts() public {
        vm.expectRevert(abi.encodeWithSelector(InvalidCriticalOp.selector));
        emergencyPause.gateCriticalOp(0);
        vm.expectRevert(abi.encodeWithSelector(InvalidCriticalOp.selector));
        emergencyPause.gateCriticalOp(3);
    }

    function testInvalidCriticalOpRevertsEvenWhilePaused() public {
        vm.prank(PAUSER);
        emergencyPause.pause();

        vm.expectRevert(abi.encodeWithSelector(InvalidCriticalOp.selector));
        emergencyPause.gateCriticalOp(0);
    }

    /**
     * @notice Reads remain available while paused (paused/pauser getters)
     */
    function testReadsAvailableWhilePaused() public {
        vm.prank(PAUSER);
        emergencyPause.pause();

        assertTrue(emergencyPause.paused());
        assertEq(emergencyPause.pauser(), PAUSER);
    }

    /**
     * @notice Document distinction: on-chain paused flag is independent of SAFE_MODE off-chain.
     * @dev This contract has no SAFE_MODE field — SAFE_MODE lives in the engine (5.7).
     *      Presence of Pausable-only surface != SAFE_MODE. Engine tests cover coexistence.
     */
    function testOnChainPauseIsNotSafeMode() public view {
        // Compile-time / interface: no safeMode / enterSafeMode on this SoT.
        assertFalse(emergencyPause.paused());
        assertEq(emergencyPause.pauser(), PAUSER);
    }
}
