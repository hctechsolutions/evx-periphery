// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {EvxPolicyLog} from "@evx-periphery/contracts/EvxPolicyLog.sol";
import {IEvxPolicyLog} from "@evx-periphery/interfaces/IEvxPolicyLog.sol";
import {OnlyPolicyKeeper, ZeroPolicyKeeper} from "@evx-periphery/libraries/PolicyLogErrors.sol";

/**
 * @title EvxPolicyLog Test Suite
 * @notice Unit tests for the Intent Engine policy observability trail (Story 1.3)
 */
contract EvxPolicyLogTest is Test {
    EvxPolicyLog private policyLog;

    address private constant POLICY_KEEPER = address(0xBEEF);
    address private constant POOL = address(0xA11CE);
    address private constant NON_KEEPER = address(0xDEAD);

    bytes32 private constant DECISION_ID = keccak256("decision-1");
    bytes32 private constant POLICY_VERSION = keccak256("policy-v1");

    function setUp() public {
        policyLog = new EvxPolicyLog(POLICY_KEEPER);
    }

    /**
     * @notice Constructor must reject zero policyKeeper
     */
    function testConstructorRejectsZeroPolicyKeeper() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroPolicyKeeper.selector));
        new EvxPolicyLog(address(0));
    }

    /**
     * @notice policyKeeper() returns the immutable address set at construction
     */
    function testPolicyKeeperIsImmutableGetter() public view {
        assertEq(policyLog.policyKeeper(), POLICY_KEEPER);
    }

    /**
     * @notice Authorized keeper emits RegimeChanged with indexed pool and decisionId
     */
    function testLogRegimeChangedSuccess() public {
        vm.prank(POLICY_KEEPER);
        vm.expectEmit(true, true, false, true);
        emit IEvxPolicyLog.RegimeChanged(POOL, 0, 1, DECISION_ID);
        policyLog.logRegimeChanged(POOL, 0, 1, DECISION_ID);
    }

    /**
     * @notice Authorized keeper emits PolicyAction with structured fields
     */
    function testLogPolicyActionSuccess() public {
        vm.prank(POLICY_KEEPER);
        vm.expectEmit(true, true, false, true);
        emit IEvxPolicyLog.PolicyAction(
            POOL,
            1, // rebalance
            42,
            DECISION_ID,
            POLICY_VERSION,
            -120,
            120,
            1500
        );
        policyLog.logPolicyAction(
            POOL,
            1,
            42,
            DECISION_ID,
            POLICY_VERSION,
            -120,
            120,
            1500
        );
    }

    /**
     * @notice Authorized keeper emits SafeModeEntered with reasonCode
     */
    function testLogSafeModeEnteredSuccess() public {
        vm.prank(POLICY_KEEPER);
        vm.expectEmit(false, false, false, true);
        emit IEvxPolicyLog.SafeModeEntered(1); // price_feed_failure
        policyLog.logSafeModeEntered(1);
    }

    /**
     * @notice Non-keeper cannot emit RegimeChanged and produces no trail
     */
    function testOnlyPolicyKeeper_logRegimeChanged() public {
        vm.recordLogs();
        vm.prank(NON_KEEPER);
        vm.expectRevert(abi.encodeWithSelector(OnlyPolicyKeeper.selector));
        policyLog.logRegimeChanged(POOL, 0, 1, DECISION_ID);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 0, "unauthorized caller must not emit events");
    }

    /**
     * @notice Non-keeper cannot emit PolicyAction and produces no trail
     */
    function testOnlyPolicyKeeper_logPolicyAction() public {
        vm.recordLogs();
        vm.prank(NON_KEEPER);
        vm.expectRevert(abi.encodeWithSelector(OnlyPolicyKeeper.selector));
        policyLog.logPolicyAction(
            POOL,
            1,
            42,
            DECISION_ID,
            POLICY_VERSION,
            -120,
            120,
            1500
        );

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 0, "unauthorized caller must not emit events");
    }

    /**
     * @notice Non-keeper cannot emit SafeModeEntered and produces no trail
     */
    function testOnlyPolicyKeeper_logSafeModeEntered() public {
        vm.recordLogs();
        vm.prank(NON_KEEPER);
        vm.expectRevert(abi.encodeWithSelector(OnlyPolicyKeeper.selector));
        policyLog.logSafeModeEntered(1);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 0, "unauthorized caller must not emit events");
    }

    /**
     * @notice Deployer / test contract is not policyKeeper by default
     */
    function testOnlyPolicyKeeper_rejectsDeployer() public {
        vm.recordLogs();
        vm.expectRevert(abi.encodeWithSelector(OnlyPolicyKeeper.selector));
        policyLog.logSafeModeEntered(4);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 0);
    }

    /**
     * @notice bytes32(0) decisionId is allowed for non-causal regime broadcasts
     */
    function testLogRegimeChangedAllowsZeroDecisionId() public {
        vm.prank(POLICY_KEEPER);
        vm.expectEmit(true, true, false, true);
        emit IEvxPolicyLog.RegimeChanged(POOL, 1, 2, bytes32(0));
        policyLog.logRegimeChanged(POOL, 1, 2, bytes32(0));
    }
}
