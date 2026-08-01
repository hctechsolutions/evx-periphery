// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ISelfPermit
 * @notice Enables this contract to perform permit-based approvals on behalf of the user.
 * @dev Supports both EIP-2612 and legacy DAI-style permits. Designed for use in multicall-compatible routers.
 */
interface ISelfPermit {
    /**
     * @notice Approves this contract to spend a specific amount of the user's tokens via EIP-2612 permit.
     * @dev Uses `msg.sender` as the signer (`owner`) and `address(this)` as the spender.
     * @param token The address of the token implementing EIP-2612.
     * @param value The amount of tokens to approve.
     * @param deadline The signature expiration timestamp.
     * @param v ECDSA signature parameter `v`.
     * @param r ECDSA signature parameter `r`.
     * @param s ECDSA signature parameter `s`.
     */
    function selfPermit(
        address token,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;

    /**
     * @notice Approves this contract to spend tokens via EIP-2612 if not already approved.
     * @dev Prevents failures if a previous approval already covers `value`. Used defensively.
     * @param token The token address.
     * @param value The amount to approve if necessary.
     * @param deadline The timestamp after which the signature is invalid.
     * @param v ECDSA signature parameter.
     * @param r ECDSA signature parameter.
     * @param s ECDSA signature parameter.
     */
    function selfPermitIfNecessary(
        address token,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;

    /**
     * @notice Approves this contract to spend tokens using a permit with `allowed` flag (e.g. DAI, CHAI).
     * @dev Uses the `permit` signature format with a boolean flag instead of `value`.
     * @param token The token address.
     * @param nonce Current nonce of the user (must match).
     * @param expiry Timestamp after which the permit is invalid.
     * @param v ECDSA signature parameter.
     * @param r ECDSA signature parameter.
     * @param s ECDSA signature parameter.
     */
    function selfPermitAllowed(
        address token,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;

    /**
     * @notice Same as `selfPermitAllowed`, but only executes if approval is necessary.
     * @dev Prevents failures due to duplicate permits.
     * @param token The token address.
     * @param nonce Current nonce of the user.
     * @param expiry Signature expiry time.
     * @param v ECDSA signature parameter.
     * @param r ECDSA signature parameter.
     * @param s ECDSA signature parameter.
     */
    function selfPermitAllowedIfNecessary(
        address token,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;
}
