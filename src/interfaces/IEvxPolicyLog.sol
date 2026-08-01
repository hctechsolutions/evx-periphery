// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IEvxPolicyLog
 * @notice Append-only on-chain observability trail for Intent Engine policy outcomes
 * @dev Events are observability only (AD-5 / AR-10). Source of truth for applied state
 *      remains on-chain contract state (`EvxPool.fee`, NPM ticks/liquidity, etc.).
 *      This interface does NOT carry `ExecutionResult` fields (txHash, executionStatus).
 *
 * Regime codes: 0=normal, 1=volatility_stress, 2=trending
 * Action codes: 0=unspecified, 1=rebalance, 2=set_dynamic_fee, 3=protective_exit, 4=pause_related
 * SAFE_MODE reason codes: 0=unspecified, 1=price_feed_failure, 2=regime_detection_failure,
 *                         3=invalid_snapshot, 4=keeper_manual
 */
interface IEvxPolicyLog {
    /**
     * @notice Emitted when a regime transition is recorded for observability
     * @dev Not authoritative for current regime — off-chain DecisionStore / domain owns regime SoT for choice
     * @param pool The pool address in context
     * @param previousRegime Prior regime code (uint8)
     * @param newRegime New regime code (uint8)
     * @param decisionId Causal decision id, or bytes32(0) when not part of a decision chain
     */
    event RegimeChanged(
        address indexed pool,
        uint8 previousRegime,
        uint8 newRegime,
        bytes32 indexed decisionId
    );

    /**
     * @notice Emitted when a policy action is recorded for observability
     * @dev Subset of AD-13 applied fields. `fee` mirrors applied fee for analytics — SoT remains EvxPool.fee + FeeUpdated
     * @param pool The pool address in context
     * @param actionCode Action kind (uint8 enum)
     * @param positionId NPM tokenId, or 0 when not applicable
     * @param decisionId Causal decision id
     * @param policyVersion Canonical off-chain PolicyConfig digest/id
     * @param tickLower Applied lower tick (observability subset)
     * @param tickUpper Applied upper tick (observability subset)
     * @param fee Applied swap fee in hundredths of a bip (observability subset)
     */
    event PolicyAction(
        address indexed pool,
        uint8 actionCode,
        uint256 positionId,
        bytes32 indexed decisionId,
        bytes32 policyVersion,
        int24 tickLower,
        int24 tickUpper,
        uint24 fee
    );

    /**
     * @notice Emitted when SAFE_MODE entry is recorded for observability
     * @dev Does NOT determine whether the system is in SAFE_MODE — operational state remains authoritative off-chain (AD-10)
     * @param reasonCode Reason for entering SAFE_MODE (uint8)
     */
    event SafeModeEntered(uint8 reasonCode);

    /**
     * @notice Returns the immutable policy keeper address authorized to write logs
     */
    function policyKeeper() external view returns (address);

    /**
     * @notice Record a regime change for observability
     * @dev Callable only by policyKeeper. Emits RegimeChanged. Does not mutate pool/NPM state.
     */
    function logRegimeChanged(
        address pool,
        uint8 previousRegime,
        uint8 newRegime,
        bytes32 decisionId
    ) external;

    /**
     * @notice Record a policy action for observability
     * @dev Callable only by policyKeeper. Emits PolicyAction. Does not mutate pool/NPM state.
     */
    function logPolicyAction(
        address pool,
        uint8 actionCode,
        uint256 positionId,
        bytes32 decisionId,
        bytes32 policyVersion,
        int24 tickLower,
        int24 tickUpper,
        uint24 fee
    ) external;

    /**
     * @notice Record SAFE_MODE entry for observability
     * @dev Callable only by policyKeeper. Emits SafeModeEntered. Does not set operational SAFE_MODE.
     */
    function logSafeModeEntered(uint8 reasonCode) external;
}
