// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Base64 } from "base64-sol/base64.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ConstructTokenURIParams, DecimalStringParams } from './NFTSharedStructs.sol';
import { NFTMetadataUtils } from "./NFTMetadataUtils.sol";
import { NFTSVGRenderer } from "./NFTSVGRenderer.sol";
import { PriceUtils } from "../PriceUtils.sol";
import { StringUtils } from "../StringUtils.sol";

/**
 * @title NFTDescriptor
 * @notice Library for generating metadata and SVG-based image URIs for position NFTs.
 * @dev Produces fully on-chain, base64-encoded ERC721 metadata and SVG images.
 */
library NFTDescriptor {
    using Strings for uint256;
    using NFTMetadataUtils for *;
    using PriceUtils for *;

    /**
     * @notice Constructs a base64-encoded token URI for a position NFT.
     * @dev The resulting URI contains JSON metadata and an SVG image embedded as `data:image/svg+xml;base64,...`.
     * @param params All metadata and rendering parameters needed to construct the URI.
     * @return uri Fully encoded `data:application/json;base64,...` token URI.
     */
    function constructTokenURI(ConstructTokenURIParams memory params) public pure returns (string memory uri) {
        string memory name = NFTMetadataUtils.generateName(params, StringUtils.feeToPercentString(params.fee));

        string memory descriptionPartOne = NFTMetadataUtils.generateDescriptionPartOne(
            params.quoteTokenSymbol.escapeQuotes(),
            params.baseTokenSymbol.escapeQuotes(),
            Strings.toHexString(uint256(uint160(params.poolAddress)), 20)
        );

        string memory descriptionPartTwo = NFTMetadataUtils.generateDescriptionPartTwo(
            params.tokenId.toString(),
            params.baseTokenSymbol.escapeQuotes(),
            Strings.toHexString(uint256(uint160(params.quoteTokenAddress)), 20),
            Strings.toHexString(uint256(uint160(params.baseTokenAddress)), 20),
            StringUtils.feeToPercentString(params.fee)
        );

        string memory image = Base64.encode(bytes(NFTSVGRenderer.generateSVGImage(params)));

        uri = string(
            abi.encodePacked(
                'data:application/json;base64,',
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name":"', name,
                            '", "description":"', descriptionPartOne, descriptionPartTwo,
                            '", "image": "data:image/svg+xml;base64,', image, '"}'
                        )
                    )
                )
            )
        );
    }
}
