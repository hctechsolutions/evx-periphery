// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title NFT Shared Structs
 * @notice Common data structures reused across the Evx Finance NFT libraries.
 */

/**
 * @notice Input object used by {NFTDescriptor.constructTokenURI} to create the metadata JSON for a position NFT.
 * @dev All numeric values are raw on‑chain units; decimals are supplied separately so that helpers can format
 *      human‑readable strings.
 * @param tokenId ERC‑721 token id that uniquely identifies the position.
 * @param quoteTokenAddress Address of the quote (price) token (e.g., USDC).
 * @param baseTokenAddress Address of the base token (e.g., ETH).
 * @param quoteTokenSymbol Symbol of the quote token, unescaped.
 * @param baseTokenSymbol Symbol of the base token, unescaped.
 * @param quoteTokenDecimals Number of decimals of the quote token (ERC‑20 `decimals()`).
 * @param baseTokenDecimals Number of decimals of the base token (ERC‑20 `decimals()`).
 * @param flipRatio If true the price ratio is inverted when building strings.
 * @param tickLower Lower tick boundary of the liquidity position.
 * @param tickUpper Upper tick boundary of the liquidity position.
 * @param tickCurrent Current pool tick when the URI is generated.
 * @param tickSpacing Tick spacing of the pool.
 * @param fee Pool fee (in hundredth of a bip, i.e. 1e‑6).
 * @param poolAddress Address of the Evx pool.
 */
struct ConstructTokenURIParams {
    uint256 tokenId;
    address quoteTokenAddress;
    address baseTokenAddress;
    string quoteTokenSymbol;
    string baseTokenSymbol;
    uint8 quoteTokenDecimals;
    uint8 baseTokenDecimals;
    bool flipRatio;
    int24 tickLower;
    int24 tickUpper;
    int24 tickCurrent;
    int24 tickSpacing;
    uint24 fee;
    address poolAddress;
}

/**
 * @notice Working buffer used by {PriceUtils.generateDecimalString}.
 * @dev The algorithm writes the decimal representation right‑to‑left inside a fixed‑size buffer.
 * @param sigfigs Significant figures to print, truncated or rounded beforehand.
 * @param bufferLength Total length of the buffer.
 * @param sigfigIndex Cursor index where the next digit will be written (moves leftwards).
 * @param decimalIndex Index where the dot '.' should be inserted (0 = no dot).
 * @param zerosStartIndex Start index (inclusive) of a run of 0's for very small/large numbers.
 * @param zerosEndIndex End index (inclusive) of the run of 0's.
 * @param isLessThanOne True if the represented number is < 1 (adds '0.' prefix).
 * @param isPercent True if the string should end with the percent sign '%'.
 */
struct DecimalStringParams {
    uint256 sigfigs;
    uint8 bufferLength;
    uint8 sigfigIndex;
    uint8 decimalIndex;
    uint8 zerosStartIndex;
    uint8 zerosEndIndex;
    bool isLessThanOne;
    bool isPercent;
}

/**
 * @notice Color stops and coordinate helpers used by {NFTSVGRenderer}.
 * @param color0 First gradient color.
 * @param color1 Second gradient color.
 * @param color2 Third gradient color.
 * @param color3 Fourth gradient color.
 * @param x1 First gradient coordinate.
 * @param y1 First gradient coordinate.
 * @param x2 Second gradient coordinate.
 * @param y2 Second gradient coordinate.
 * @param x3 Text anchor coordinate.
 * @param y3 Text anchor coordinate.
 */
struct VisualParams {
    string color0;
    string color1;
    string color2;
    string color3;
    string x1;
    string y1;
    string x2;
    string y2;
    string x3;
    string y3;
}

/**
 * @notice Human-readable pool metadata consumed by the SVG renderer.
 * @param quoteToken Token address in string format.
 * @param baseToken Token address in string format.
 * @param poolAddress Address of the liquidity pool.
 * @param quoteTokenSymbol Escaped symbol of the quote token.
 * @param baseTokenSymbol Escaped symbol of the base token.
 * @param feeTier Fee tier formatted as a string.
 * @param tokenId NFT identifier.
 */
struct PoolParams {
    string quoteToken;
    string baseToken;
    address poolAddress;
    string quoteTokenSymbol;
    string baseTokenSymbol;
    string feeTier;
    uint256 tokenId;
}

/**
 * @notice Tick data used to render grid and range highlights in the position SVG.
 * @param tickLower Lower bound of the range.
 * @param tickUpper Upper bound of the range.
 * @param tickSpacing Pool's tick spacing.
 * @param overRange Signed indicator (‑1 = below, 1 = above, 0 = in range).
 */
struct TickParams {
    int24 tickLower;
    int24 tickUpper;
    int24 tickSpacing;
    int8 overRange;
}

/**
 * @notice Aggregate parameters required by {NFTSVGRenderer.generateSVGImage}.
 * @dev Combines metadata, range and style parameters into a single struct.
 * @param quoteToken Human-readable quote token address.
 * @param baseToken Human-readable base token address.
 * @param poolAddress Liquidity pool address.
 * @param quoteTokenSymbol Escaped symbol of the quote token.
 * @param baseTokenSymbol Escaped symbol of the base token.
 * @param feeTier Pool fee tier formatted as a string.
 * @param tickLower Lower bound of the position.
 * @param tickUpper Upper bound of the position.
 * @param tickSpacing Tick spacing of the pool.
 * @param overRange Signed range indicator.
 * @param tokenId NFT ID of the position.
 * @param color0 First gradient color.
 * @param color1 Second gradient color.
 * @param color2 Third gradient color.
 * @param color3 Fourth gradient color.
 * @param x1 Gradient or layout coordinate.
 * @param y1 Gradient or layout coordinate.
 * @param x2 Gradient or layout coordinate.
 * @param y2 Gradient or layout coordinate.
 * @param x3 Text layout coordinate.
 * @param y3 Text layout coordinate.
 */
struct SVGParams {
    string quoteToken;
    string baseToken;
    address poolAddress;
    string quoteTokenSymbol;
    string baseTokenSymbol;
    string feeTier;
    int24 tickLower;
    int24 tickUpper;
    int24 tickSpacing;
    int8 overRange;
    uint256 tokenId;
    string color0;
    string color1;
    string color2;
    string color3;
    string x1;
    string y1;
    string x2;
    string y2;
    string x3;
    string y3;
}