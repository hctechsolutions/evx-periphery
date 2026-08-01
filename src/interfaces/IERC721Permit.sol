// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

/**
 * @title IERC721Permit
 * @notice Extension of ERC721 that allows approvals via off-chain signatures (EIP-4494).
 * @dev Enables gasless approvals by signing a message off-chain and submitting it via `permit`.
 */
interface IERC721Permit is IERC721 {
    /**
     * @notice Returns the EIP-712 typehash used to generate permit digests.
     * @return The typehash constant used in signature encoding.
     */
    function PERMIT_TYPEHASH() external pure returns (bytes32);

    /**
     * @notice Returns the domain separator used in EIP-712 permit signatures.
     * @return The domain separator for the current chain and contract instance.
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /**
     * @notice Approves a spender to transfer a specific token ID using a signed message.
     * @dev Follows EIP-712 encoding. Caller must not be `spender`. Signature must be from the token owner.
     *
     * @param spender The address being approved to manage the token.
     * @param tokenId The ID of the token to approve.
     * @param deadline A timestamp after which the signature becomes invalid.
     * @param v Recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     */
    function permit(
        address spender,
        uint256 tokenId,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;
}
