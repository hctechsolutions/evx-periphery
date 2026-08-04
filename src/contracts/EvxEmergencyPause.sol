// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IEvxEmergencyPause} from "@evx-periphery/interfaces/IEvxEmergencyPause.sol";
import {
    OnlyPauser,
    ZeroPauser,
    EnforcedPause,
    ExpectedPause,
    InvalidCriticalOp
} from "@evx-periphery/libraries/EmergencyPauseErrors.sol";

/**
 * @title EvxEmergencyPause
 * @notice Dedicated on-chain emergency pause registry + consultative view gate for keeper ops
 * @dev Story 5.8 / FR19 / NFR8 / NFR11. Placement: `evx-periphery` (policy/ops), not EvxPool/NPM
 *      hot path — avoids Pausable on cloneable pools and permissionless mint for PoC.
 *
 *      **SAFE_MODE ≠ this contract.** SAFE_MODE (5.7) is off-chain keeper degradation and must
 *      not auto-call `pause()`. This flag does not enter SAFE_MODE. Both may coexist.
 *
 *      ACL: single immutable `pauser` for pause and unpause (PAUSER/UNPAUSER split deferred).
 *      Gate is view-only: engine `eth_call`s `paused` / `gateCriticalOp` before broadcast.
 */
contract EvxEmergencyPause is IEvxEmergencyPause {
    /// @dev PoC gate codes — keep in sync with IEvxEmergencyPause NatSpec
    uint8 private constant OP_REBALANCE = 1;
    uint8 private constant OP_SET_DYNAMIC_FEE = 2;

    /// @inheritdoc IEvxEmergencyPause
    address public immutable override pauser;

    /// @inheritdoc IEvxEmergencyPause
    bool public override paused;

    modifier onlyPauser() {
        if (msg.sender != pauser) revert OnlyPauser();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert ExpectedPause();
        _;
    }

    /**
     * @notice Sets the immutable pauser authorized for pause and unpause
     * @param _pauser Address of the operator / ACL principal (must be non-zero)
     */
    constructor(address _pauser) {
        if (_pauser == address(0)) revert ZeroPauser();
        pauser = _pauser;
    }

    /// @inheritdoc IEvxEmergencyPause
    function pause() external override onlyPauser whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    /// @inheritdoc IEvxEmergencyPause
    function unpause() external override onlyPauser whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    /// @inheritdoc IEvxEmergencyPause
    function requireNotPaused() external view override {
        if (paused) revert EnforcedPause();
    }

    /// @inheritdoc IEvxEmergencyPause
    function gateCriticalOp(uint8 opCode) external view override {
        // Validate op code before pause so InvalidCriticalOp is stable while paused.
        if (opCode != OP_REBALANCE && opCode != OP_SET_DYNAMIC_FEE) revert InvalidCriticalOp();
        if (paused) revert EnforcedPause();
    }
}
