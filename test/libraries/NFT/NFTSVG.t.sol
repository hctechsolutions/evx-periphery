// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-periphery/libraries/NFT/NFTSVG.sol";
import "@evx-periphery/libraries/NFT/NFTSharedStructs.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract NFTSVGTest is Test {
    using Strings for uint256;

    string private constant CURVE1 = "M1 1C41 41 105 105 145 145";
    string private constant CURVE2 = "M1 1C33 49 97 113 145 145";
    string private constant CURVE4 = "M1 1C25 65 81 121 145 145";
    string private constant CURVE8 = "M1 1C1 97 49 145 145 145";

    PoolParams pool;
    TickParams tick;
    VisualParams visual;

    function setUp() public {
        pool = PoolParams({
            quoteToken: "0x109b39d11aE5036A7E14458A769F20d55f7F28da",
            baseToken: "0x8B6b1DC75e232F3D41D26A8439B2141AEaf49663",
            poolAddress: address(0x00D5f45956f9c09C15379369d892904bF46Cbab6),
            quoteTokenSymbol: "ETH",
            baseTokenSymbol: "USDC",
            feeTier: "0.3%",
            tokenId: 1
        });

        tick = TickParams({
            tickLower: -40,
            tickUpper: 40,
            tickSpacing: 60,
            overRange: 0
        });

        visual = VisualParams({
            color0: "011C40",
            color1: "04D939",
            color2: "011C40",
            color3: "04D939",
            x1: "80",
            y1: "80",
            x2: "100",
            y2: "100",
            x3: "120",
            y3: "120"
      });
    }

    function testGenerateSVG_NotEmpty() public view {
        string memory svg = NFTSVG.generateSVG(pool, tick, visual);
        assertGt(bytes(svg).length, 0, "SVG empty");
        assertTrue(_contains(svg, "<svg"), "missing <svg> tag");
    }

    function testGetCurve_Selections() public pure {
        // ≤4 → CURVE1
        assertEq(NFTSVG.getCurve(-60, 60, 60), CURVE1, "curve1 mismatch");
        // 5‑8 → CURVE2
        assertEq(NFTSVG.getCurve(-120, 240, 60), CURVE2, "curve2 mismatch");
        // 17‑32 → CURVE4
        assertEq(NFTSVG.getCurve(-480, 1440, 60), CURVE4, "curve4 mismatch");
        // >256 → CURVE8
        assertEq(NFTSVG.getCurve(-18000, 18000, 60), CURVE8, "curve8 mismatch");
    }

    function testRangeLocation_Mapping() public pure {
        // Case 1: very low midpoint → (8,7)
        (string memory x1, string memory y1) = NFTSVG.rangeLocation(-130000, -126000);
        assertEq(x1, "8", "x1");
        assertEq(y1, "7", "y1");

        // Case 2: low midpoint → (8,10.5)
        (string memory x2, string memory y2) = NFTSVG.rangeLocation(-100000, -90000);
        assertEq(x2, "8", "x2");
        assertEq(y2, "10.5", "y2");

        // Case 3: near zero negative → (10,18)
        (string memory x3, string memory y3) = NFTSVG.rangeLocation(-20000, -10000);
        assertEq(x3, "10", "x3");
        assertEq(y3, "18", "y3");

        // Case 4: positive small → (18,26)
        (string memory x4, string memory y4) = NFTSVG.rangeLocation(26000, 27000);
        assertEq(x4, "18", "x4");
        assertEq(y4, "26", "y4");
    }

    function testIsRare_OutputDiversity() public pure {
        uint256 rareCount;
        address poolAddr = address(0x1234);
        for (uint256 id = 1; id <= 256; ++id) {
            if (NFTSVG.isRare(id, poolAddr)) rareCount++;
        }
        // Expect at least one but clearly not all rare tokens.
        assertGt(rareCount, 0, "no rares generated");
        assertLt(rareCount, 256, "all rares unlikely");
    }

    function _contains(string memory haystack, string memory needle) internal pure returns (bool) {
        bytes memory h = bytes(haystack);
        bytes memory n = bytes(needle);
        if (n.length > h.length) return false;
        for (uint256 i; i <= h.length - n.length; ++i) {
            bool matchFound = true;
            for (uint256 j; j < n.length; ++j) {
                if (h[i + j] != n[j]) {
                    matchFound = false;
                    break;
                }
            }
            if (matchFound) return true;
        }
        return false;
    }
}
