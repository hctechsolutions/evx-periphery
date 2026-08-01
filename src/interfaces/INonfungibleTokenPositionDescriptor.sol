// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import './INonfungiblePositionManager.sol';

/**
 * @title INonfungibleTokenPositionDescriptor
 * @notice Interface for generating token URIs for NFT-wrapped liquidity positions.
 * @dev Used by position managers to render SVG-based or JSON metadata URIs.
 */
interface INonfungibleTokenPositionDescriptor {
    /**
     * @notice Returns the metadata URI for a given position token.
     * @dev The returned URI may be a base64-encoded `data:` URI containing JSON metadata.
     * Frontends should support both on-chain and off-chain formats.
     *
     * @param positionManager The position manager that owns the position.
     * @param tokenId The ID of the NFT representing the position.
     * @return The metadata URI (typically an ERC721-compatible JSON or SVG).
     */
    function tokenURI(INonfungiblePositionManager positionManager, uint256 tokenId)
        external
        view
        returns (string memory);
}
