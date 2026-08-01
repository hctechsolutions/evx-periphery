// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC1271
 * @notice Interface for validating signatures from smart contract wallets.
 * @dev Defined in EIP-1271. Enables signature verification for non-EOA accounts (e.g., Gnosis Safe).
 */
interface IERC1271 {
    /**
     * @notice Checks whether a given signature is valid for a specific hash.
     * @dev This function MUST return the magic value `0x1626ba7e` if the signature is valid.
     * Implementations MUST be `view` and MUST allow external calls.
     * Commonly used for verifying off-chain signed data by smart contract wallets.
     *
     * @param hash The keccak256 hash of the signed message.
     * @param signature The signature bytes (usually 65 bytes: r + s + v).
     * @return magicValue The magic value 0x1626ba7e if valid, otherwise any other value to indicate failure.
     */
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue);
}
