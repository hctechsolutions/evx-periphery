// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC20PermitAllowed
 * @notice Permit interface used by legacy tokens like DAI and CHAI for off-chain approvals.
 * @dev Unlike EIP-2612, this interface uses a boolean `allowed` instead of a value.
 * Used for gasless approvals via signature with unlimited or zero allowance.
 */
interface IERC20PermitAllowed {
    /**
     * @notice Approves or revokes a spender's allowance via an off-chain signature.
     * @dev This signature-based approval follows the DAI/CHAI pattern (non-EIP-2612).
     * If `allowed` is true, allowance is set to `type(uint256).max`, else set to 0.
     * Reverts if signature is invalid or expired.
     *
     * @param holder The address of the token owner who signed the permit.
     * @param spender The address being granted or revoked permission to spend.
     * @param nonce The current nonce of the holder; must match the expected value.
     * @param expiry A timestamp after which the permit is no longer valid.
     * @param allowed If true, sets allowance to max; if false, sets to 0.
     * @param v Recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     */
    function permit(
        address holder,
        address spender,
        uint256 nonce,
        uint256 expiry,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}
