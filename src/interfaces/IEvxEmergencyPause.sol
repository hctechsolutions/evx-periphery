// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IEvxEmergencyPause
 * @notice On-chain emergency pause/unpause under a single ACL (FR19 / NFR8 / NFR11)
 * @dev Distinct from keeper SAFE_MODE (Story 5.7 / AD-10): SAFE_MODE is off-chain degradation
 *      that freezes the keeper's own mutations; this contract is on-chain SoT for the pause
 *      flag. Callers of the consultative gate (`requireNotPaused` / `gateCriticalOp`) revert
 *      while `paused`. EvxPool/NPM are not hard-wired in PoC — the keeper must consult this
 *      SoT before broadcasting. Neither SAFE_MODE nor pause implies the other.
 *
 * PoC critical op codes (gate surface; mirrors PolicyLog action semantics subset):
 *   1 = rebalance / NPM mint-burn path
 *   2 = set_dynamic_fee
 *
 * NFR8: Anvil/Foundry proves pause is confirmable in one PoC block. Arbitrum &lt; 1 block
 * is an integration/testnet property when that environment is exercised — not claimed
 * solely from Anvil mining.
 */
interface IEvxEmergencyPause {
    /**
     * @notice Emitted when an authorized pauser freezes critical ops
     * @param account The pauser that executed pause
     */
    event Paused(address account);

    /**
     * @notice Emitted when an authorized pauser clears the freeze
     * @param account The pauser that executed unpause
     */
    event Unpaused(address account);

    /**
     * @notice Immutable address authorized for both pause and unpause (single ACL)
     */
    function pauser() external view returns (address);

    /**
     * @notice Whether the emergency pause flag is currently set
     */
    function paused() external view returns (bool);

    /**
     * @notice Freeze critical gated operations (same ACL as unpause)
     * @dev Reverts `OnlyPauser` / `EnforcedPause` (already paused). Confirmable in one PoC block.
     */
    function pause() external;

    /**
     * @notice Clear the freeze (same ACL as pause)
     * @dev Reverts `OnlyPauser` / `ExpectedPause` (not paused).
     */
    function unpause() external;

    /**
     * @notice View gate: reverts `EnforcedPause` while paused; no-op when not paused
     * @dev Keeper / integrators may `eth_call` this (or `paused()`) before mutating on-chain.
     *      Pure reads of protocol state remain available while paused.
     */
    function requireNotPaused() external view;

    /**
     * @notice View gate for a PoC-critical op code — reverts while paused or on invalid code
     * @param opCode 1=rebalance / NPM mint-burn path, 2=set_dynamic_fee
     * @dev View-only (no events, no state). Validates `opCode` before pause so invalid codes
     *      always revert `InvalidCriticalOp` even while paused. Does not mutate EvxPool/NPM.
     */
    function gateCriticalOp(uint8 opCode) external view;
}
