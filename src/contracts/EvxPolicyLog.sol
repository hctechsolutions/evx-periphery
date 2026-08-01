// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IEvxPolicyLog} from "@evx-periphery/interfaces/IEvxPolicyLog.sol";
import {OnlyPolicyKeeper, ZeroPolicyKeeper} from "@evx-periphery/libraries/PolicyLogErrors.sol";

/**
 * @title EvxPolicyLog
 * @notice Append-only policy observability log writable solely by policyKeeper
 * @dev Events are observability only (AD-5 / AR-10). This contract stores no regime,
 *      SAFE_MODE, or last-action state — chain state of EvxPool / NPM remains the
 *      source of truth for applied settlement. Enum range validation is the caller's
 *      responsibility; writers always emit when authorized.
 */
contract EvxPolicyLog is IEvxPolicyLog {
    /// @inheritdoc IEvxPolicyLog
    address public immutable override policyKeeper;

    modifier onlyPolicyKeeper() {
        if (msg.sender != policyKeeper) revert OnlyPolicyKeeper();
        _;
    }

    /**
     * @notice Sets the immutable policy keeper authorized to emit log events
     * @param _policyKeeper Address of the keeper process (must be non-zero)
     */
    constructor(address _policyKeeper) {
        if (_policyKeeper == address(0)) revert ZeroPolicyKeeper();
        policyKeeper = _policyKeeper;
    }

    /// @inheritdoc IEvxPolicyLog
    function logRegimeChanged(
        address pool,
        uint8 previousRegime,
        uint8 newRegime,
        bytes32 decisionId
    ) external override onlyPolicyKeeper {
        emit RegimeChanged(pool, previousRegime, newRegime, decisionId);
    }

    /// @inheritdoc IEvxPolicyLog
    function logPolicyAction(
        address pool,
        uint8 actionCode,
        uint256 positionId,
        bytes32 decisionId,
        bytes32 policyVersion,
        int24 tickLower,
        int24 tickUpper,
        uint24 fee
    ) external override onlyPolicyKeeper {
        emit PolicyAction(
            pool,
            actionCode,
            positionId,
            decisionId,
            policyVersion,
            tickLower,
            tickUpper,
            fee
        );
    }

    /// @inheritdoc IEvxPolicyLog
    function logSafeModeEntered(uint8 reasonCode) external override onlyPolicyKeeper {
        emit SafeModeEntered(reasonCode);
    }
}
