// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-periphery/libraries/NFT/NFTSharedStructs.sol";
import "@evx-periphery/libraries/NFT/NFTSVGRenderer.sol";

contract NFTSVGRendererTest is Test {
    using Strings for uint256;

    ConstructTokenURIParams params;

    function setUp() public {
        params = ConstructTokenURIParams({
            tokenId: 7,
            quoteTokenAddress: address(0x1111),
            baseTokenAddress: address(0x2222),
            quoteTokenSymbol: "USDC",
            baseTokenSymbol: "ETH",
            quoteTokenDecimals: 6,
            baseTokenDecimals: 18,
            flipRatio: false,
            tickLower: -120,
            tickUpper: 120,
            tickCurrent: 0,
            tickSpacing: 60,
            fee: 3000,                // start with integer‑percent branch
            poolAddress: address(0x3333)
        });
    }

    /**
     * @notice Fee with zero fractional part returns a plain percentage string.
     */
    function testGenerateSVGImageReturnsNonEmpty() public {
        string memory out = NFTSVGRenderer.generateSVGImage(params);
        assertTrue(bytes(out).length > 0, "SVG output must not be empty");
    }

    /**
     * @notice Fee with fractional part returns a full SVG (contains <svg tag).
     */
    function testGenerateSVGImage_FractionalFeeReturnsSVG() public {
        params.fee = 3050; // 30.50 ‑ triggers SVG branch
        string memory svg = NFTSVGRenderer.generateSVGImage(params);
        assertTrue(bytes(svg).length > 0, "SVG should not be empty");
        // crude check that we indeed got an SVG snippet
        bytes memory tag = bytes("<svg");
        bool found;
        for (uint256 i; i + tag.length <= bytes(svg).length; ++i) {
            bool ok = true;
            for (uint256 j; j < tag.length; ++j) {
                if (bytes(svg)[i + j] != tag[j]) { ok = false; break; }
            }
            if (ok) { found = true; break; }
        }
        assertTrue(found, "<svg tag missing");
    }

    /**
     * @notice Colour generation is deterministic for same addresses.
     */
    function testColorGenerationDeterminism() public view {
        (
            string memory c0a, string memory c1a, string memory c2a, string memory c3a
        ) = NFTSVGRenderer.prepareColors(params);

        (
            string memory c0b, string memory c1b, string memory c2b, string memory c3b
        ) = NFTSVGRenderer.prepareColors(params);

        assertEq(c0a, c0b, "color0 not deterministic");
        assertEq(c1a, c1b, "color1 not deterministic");
        assertEq(c2a, c2b, "color2 not deterministic");
        assertEq(c3a, c3b, "color3 not deterministic");
    }
}
