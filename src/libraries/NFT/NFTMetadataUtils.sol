// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ConstructTokenURIParams } from '@evx-periphery/libraries/NFT/NFTSharedStructs.sol';
import '@evx-periphery/libraries/PriceUtils.sol';
import '@evx-core/libraries/TickMath.sol';

/**
 * @title NFTMetadataUtils
 * @notice Library for generating human-readable metadata strings for position NFTs.
 * @dev Used in the NFTDescriptor to build names and descriptions dynamically.
 */
library NFTMetadataUtils {

    /**
     * @notice Constructs the display name of the NFT position.
     * @dev Combines fee tier, token symbols and price range to form a unique identifier.
     * @param params Struct containing token and price data.
     * @param feeTier The human-readable fee percentage string.
     * @return The constructed name string.
     */
    function generateName(ConstructTokenURIParams memory params, string memory feeTier)
        external
        pure
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    'Evx - ',
                    feeTier,
                    ' - ',
                    escapeQuotes(params.quoteTokenSymbol),
                    '/',
                    escapeQuotes(params.baseTokenSymbol),
                    ' - ',
                    PriceUtils.tickToDecimalString(
                        !params.flipRatio ? params.tickLower : params.tickUpper,
                        params.tickSpacing,
                        params.baseTokenDecimals,
                        params.quoteTokenDecimals,
                        params.flipRatio
                    ),
                    '<>',
                    PriceUtils.tickToDecimalString(
                        !params.flipRatio ? params.tickUpper : params.tickLower,
                        params.tickSpacing,
                        params.baseTokenDecimals,
                        params.quoteTokenDecimals,
                        params.flipRatio
                    )
                )
            );
    }

    /**
     * @notice Escapes all double quotes in a string.
     * @dev Used to safely include symbols inside JSON string values.
     * @param symbol Input string that may contain `"`.
     * @return escaped String with `"` characters escaped as `\"`.
     */
    function escapeQuotes(string memory symbol) internal pure returns (string memory escaped) {
        bytes memory symbolBytes = bytes(symbol);
        uint8 quotesCount = 0;
        for (uint8 i = 0; i < symbolBytes.length; i++) {
            if (symbolBytes[i] == '"') {
                quotesCount++;
            }
        }
        if (quotesCount > 0) {
            bytes memory escapedBytes = new bytes(symbolBytes.length + quotesCount);
            uint256 index;
            for (uint8 i = 0; i < symbolBytes.length; i++) {
                if (symbolBytes[i] == '"') {
                    escapedBytes[index++] = '\\';
                }
                escapedBytes[index++] = symbolBytes[i];
            }
            return string(escapedBytes);
        }
        return symbol;
    }

    /**
     * @notice Builds the first part of the description field for the NFT metadata.
     * @dev Contains general info about the pool and its tokens.
     * @param quoteTokenSymbol The symbol of the quote token.
     * @param baseTokenSymbol The symbol of the base token.
     * @param poolAddress The hexadecimal address of the Evx pool.
     * @return description A formatted string including token info and pool address.
     */
    function generateDescriptionPartOne(
        string memory quoteTokenSymbol,
        string memory baseTokenSymbol,
        string memory poolAddress
    ) internal pure returns (string memory description) {
        return string(
            abi.encodePacked(
                "This NFT represents a liquidity position in a Evx ",
                quoteTokenSymbol,
                "-",
                baseTokenSymbol,
                " pool. The owner of this NFT can modify or redeem the position.\\n\\n",
                "Pool Address: ",
                poolAddress,
                "\\n",
                quoteTokenSymbol
            )
        );
    }

    /**
     * @notice Builds the second part of the description field for the NFT metadata.
     * @dev Includes token addresses, fee tier and token ID. Ends with a disclaimer.
     * @param tokenId The ID of the position NFT.
     * @param baseTokenSymbol The symbol of the base token.
     * @param quoteTokenAddress The address of the quote token.
     * @param baseTokenAddress The address of the base token.
     * @param feeTier The fee tier of the pool as a percentage string.
     * @return description A formatted string with technical details and a warning.
     */
    function generateDescriptionPartTwo(
        string memory tokenId,
        string memory baseTokenSymbol,
        string memory quoteTokenAddress,
        string memory baseTokenAddress,
        string memory feeTier
    ) internal pure returns (string memory description) {
        return string(
            abi.encodePacked(
                " Address: ", quoteTokenAddress,
                "\\n",
                baseTokenSymbol,
                " Address: ", baseTokenAddress,
                "\\nFee Tier: ", feeTier,
                "\\nToken ID: ", tokenId,
                "\\n\\n",
                unicode"⚠️ DISCLAIMER: Due diligence is imperative when assessing this NFT. ",
                "Make sure token addresses match the expected tokens, as token symbols may be imitated."
            )
        );
    }
}
