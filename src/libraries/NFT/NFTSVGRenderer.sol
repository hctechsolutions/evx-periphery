// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ConstructTokenURIParams, PoolParams, VisualParams, TickParams } from './NFTSharedStructs.sol';
import { StringUtils } from "../StringUtils.sol";
import { HexStrings } from "../HexStrings.sol";
import './NFTSVG.sol';

/**
 * @title NFTSVGRenderer
 * @notice Assembles all required parameters and produces the final SVG markup for an NFT position.
 * @dev Handles coordinate and color generation based on token address and ID entropy.
 */
library NFTSVGRenderer {
    /**
     * @notice Converts an address into a hex string with 0x prefix.
     * @param addr The address to convert.
     * @return The hexadecimal string representation of the address.
     */
    function addressToString(address addr) internal pure returns (string memory) {
        return HexStrings.toHexString(uint256(uint160(addr)), 20);
    }

    /**
     * @notice Encodes the quote and base token addresses as strings.
     */
    function prepareAddresses(ConstructTokenURIParams memory params) internal pure returns (string memory quoteTokenStr, string memory baseTokenStr) {
        quoteTokenStr = addressToString(params.quoteTokenAddress);
        baseTokenStr = addressToString(params.baseTokenAddress);
    }

    /**
     * @notice Generates 4 colors for the background gradient and UI layers.
     */
    function prepareColors(ConstructTokenURIParams memory params) internal pure returns (string memory c0, string memory c1, string memory c2, string memory c3) {
        c0 = tokenToColorHex(uint256(uint160(params.quoteTokenAddress)), 136);
        c1 = tokenToColorHex(uint256(uint160(params.baseTokenAddress)), 136);
        c2 = tokenToColorHex(uint256(uint160(params.quoteTokenAddress)), 0);
        c3 = tokenToColorHex(uint256(uint160(params.baseTokenAddress)), 0);
    }

    /**
     * @notice Computes deterministic gradient and layout coordinates based on token addresses and token ID.
     */
    function prepareCoords(ConstructTokenURIParams memory params) internal pure returns (
        string memory x1, string memory y1,
        string memory x2, string memory y2,
        string memory x3, string memory y3
    ) {
        x1 = scale(getCircleCoord(uint256(uint160(params.quoteTokenAddress)), 16, params.tokenId), 0, 255, 16, 274);
        y1 = scale(getCircleCoord(uint256(uint160(params.baseTokenAddress)), 16, params.tokenId), 0, 255, 100, 484);
        x2 = scale(getCircleCoord(uint256(uint160(params.quoteTokenAddress)), 32, params.tokenId), 0, 255, 16, 274);
        y2 = scale(getCircleCoord(uint256(uint160(params.baseTokenAddress)), 32, params.tokenId), 0, 255, 100, 484);
        x3 = scale(getCircleCoord(uint256(uint160(params.quoteTokenAddress)), 48, params.tokenId), 0, 255, 16, 274);
        y3 = scale(getCircleCoord(uint256(uint160(params.baseTokenAddress)), 48, params.tokenId), 0, 255, 100, 484);
    }

    /**
     * @notice Entry point to construct the full SVG markup for the NFT.
     * @param params Struct containing all NFT metadata and rendering information.
     * @return svg A full SVG string ready to be base64-encoded.
     */
    function generateSVGImage(ConstructTokenURIParams memory params) external pure returns (string memory svg) {
        PoolParams memory poolParams = PoolParams({
            quoteToken: addressToString(params.quoteTokenAddress),
            baseToken: addressToString(params.baseTokenAddress),
            poolAddress: params.poolAddress,
            quoteTokenSymbol: params.quoteTokenSymbol,
            baseTokenSymbol: params.baseTokenSymbol,
            feeTier: StringUtils.feeToPercentString(params.fee),
            tokenId: params.tokenId
        });

        VisualParams memory visualParams = VisualParams({
            color0: tokenToColorHex(uint256(uint160(params.quoteTokenAddress)), 136),
            color1: tokenToColorHex(uint256(uint160(params.baseTokenAddress)), 136),
            color2: tokenToColorHex(uint256(uint160(params.quoteTokenAddress)), 0),
            color3: tokenToColorHex(uint256(uint160(params.baseTokenAddress)), 0),
            x1: scale(getCircleCoord(uint256(uint160(params.quoteTokenAddress)), 16, params.tokenId), 0, 255, 16, 274),
            y1: scale(getCircleCoord(uint256(uint160(params.baseTokenAddress)), 16, params.tokenId), 0, 255, 100, 484),
            x2: scale(getCircleCoord(uint256(uint160(params.quoteTokenAddress)), 32, params.tokenId), 0, 255, 16, 274),
            y2: scale(getCircleCoord(uint256(uint160(params.baseTokenAddress)), 32, params.tokenId), 0, 255, 100, 484),
            x3: scale(getCircleCoord(uint256(uint160(params.quoteTokenAddress)), 48, params.tokenId), 0, 255, 16, 274),
            y3: scale(getCircleCoord(uint256(uint160(params.baseTokenAddress)), 48, params.tokenId), 0, 255, 100, 484)
        });

        TickParams memory tickParams = TickParams({
            tickLower: params.tickLower,
            tickUpper: params.tickUpper,
            tickSpacing: params.tickSpacing,
            overRange: overRange(params.tickLower, params.tickUpper, params.tickCurrent)
        });

        return NFTSVG.generateSVG(poolParams, tickParams, visualParams);
    }

    /**
     * @notice Determines whether the current tick is inside, above, or below the position.
     */
    function overRange(
        int24 tickLower,
        int24 tickUpper,
        int24 tickCurrent
    ) private pure returns (int8) {
        if (tickCurrent < tickLower) return -1;
        else if (tickCurrent > tickUpper) return 1;
        else return 0;
    }

    /**
     * @notice Linearly interpolates an integer into a different range and returns as string.
     */
    function scale(
        uint256 n,
        uint256 inMn,
        uint256 inMx,
        uint256 outMn,
        uint256 outMx
    ) private pure returns (string memory) {
        return Strings.toString(((n - inMn) * (outMx - outMn)) / (inMx - inMn) + outMn);
    }

    /**
     * @notice Extracts a short hex color string from the token address.
     */
    function tokenToColorHex(uint256 token, uint256 offset) internal pure returns (string memory str) {
        return HexStrings.toHexStringNoPrefix(uint256(token >> offset), 3);
    }

    /**
     * @notice Computes a circle coordinate used for gradient placement.
     */
    function getCircleCoord(
        uint256 tokenAddress,
        uint256 offset,
        uint256 tokenId
    ) internal pure returns (uint256) {
        return (sliceTokenHex(tokenAddress, offset) * tokenId) % 255;
    }

    /**
     * @notice Extracts a byte from the token address for use in rendering entropy.
     */
    function sliceTokenHex(uint256 token, uint256 offset) internal pure returns (uint256) {
        return uint256(uint8(token >> offset));
    }
} 
