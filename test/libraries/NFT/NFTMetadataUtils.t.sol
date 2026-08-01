// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import "@evx-periphery/libraries/NFT/NFTSharedStructs.sol";
import "@evx-periphery/libraries/NFT/NFTMetadataUtils.sol";
import "@evx-periphery/libraries/NFT/NFTDescriptor.sol";
import "@evx-periphery/libraries/StringUtils.sol";
import "@evx-periphery/libraries/PriceUtils.sol";
import "@evx-core/libraries/TickMath.sol";


contract NFTMetadataUtilsTest is Test {
    using Strings for uint256;

    ConstructTokenURIParams params;

    function setUp() public {
        params = ConstructTokenURIParams({
            tokenId: 42,
            quoteTokenAddress: address(0x1111),
            baseTokenAddress: address(0x2222),
            quoteTokenSymbol: 'USDC"',
            baseTokenSymbol: 'ETH"',
            quoteTokenDecimals: 6,
            baseTokenDecimals: 18,
            flipRatio: false,
            tickLower: -120,
            tickUpper: 120,
            tickCurrent: 0,
            tickSpacing: 60,
            fee: 500,                 // 0.05 %
            poolAddress: address(0x3333)
        });
    }

    function testEscapeQuotes() public pure {
        string memory s = NFTMetadataUtils.escapeQuotes('A"B"C');
        assertEq(s, 'A\\"B\\"C');
    }

    function testDescriptionsNotEmpty() public view {
        string memory part1 = NFTMetadataUtils.generateDescriptionPartOne(
            params.quoteTokenSymbol,
            params.baseTokenSymbol,
            Strings.toHexString(uint256(uint160(params.poolAddress)), 20)
        );
        string memory part2 = NFTMetadataUtils.generateDescriptionPartTwo(
            params.tokenId.toString(),
            params.baseTokenSymbol,
            Strings.toHexString(uint256(uint160(params.quoteTokenAddress)), 20),
            Strings.toHexString(uint256(uint160(params.baseTokenAddress)), 20),
            StringUtils.feeToPercentString(params.fee)
        );

        assertTrue(bytes(part1).length > 0, "part1 empty");
        assertTrue(bytes(part2).length > 0, "part2 empty");
        assertTrue(_contains(part1, '\\n'), "part1 missing \\n");
        assertTrue(_contains(part2, 'DISCLAIMER'), "part2 missing disclaimer");
    }

    function testGenerateName() public view {
        string memory name = NFTMetadataUtils.generateName(
            params,
            StringUtils.feeToPercentString(params.fee)
        );

        // nome não pode ser vazio e deve conter feeTier + símbolos escapados + faixa
        assertTrue(bytes(name).length > 0, "name empty");
        assertTrue(_contains(name, '0.05%'), "fee tier absent");
        assertTrue(_contains(name, 'USDC\\"/ETH\\"'), "symbols absent");
        assertTrue(_contains(name, '<>'), "range separator absent");
    }

    function testGenerateNameExtremeTicks() public {
        // usa limites do TickMath para garantir que não dá underflow
        params.tickLower = TickMath.MIN_TICK;     // -887272
        params.tickUpper = TickMath.MIN_TICK + int24(params.tickSpacing);

        string memory name = NFTMetadataUtils.generateName(
            params,
            StringUtils.feeToPercentString(params.fee)
        );
        assertTrue(bytes(name).length > 0);
    }

    function _contains(string memory haystack, string memory needle) internal pure returns (bool) {
        bytes memory h = bytes(haystack);
        bytes memory n = bytes(needle);
        if (n.length > h.length) return false;
        for (uint256 i = 0; i <= h.length - n.length; i++) {
            bool matchFound = true;
            for (uint256 j = 0; j < n.length; j++) {
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
