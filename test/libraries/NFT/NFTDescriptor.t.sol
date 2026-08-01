// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-periphery/libraries/NFT/NFTDescriptor.sol";
import "@evx-periphery/libraries/NFT/NFTSharedStructs.sol";
import "@evx-periphery/libraries/StringUtils.sol";
import "base64-sol/base64.sol";


contract NFTDescriptorTest is Test {
    using Strings for uint256;

    ConstructTokenURIParams params;

    function setUp() public {
        params = ConstructTokenURIParams({
            tokenId: 1,
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
            fee: 3000,
            poolAddress: address(0x3333)
        });
    }

    function testConstructTokenURI_JSONFormat() public view {
        string memory uri = NFTDescriptor.constructTokenURI(params);
        assertTrue(bytes(uri).length > 0, "URI must not be empty");

        string memory prefix = "data:application/json;base64,";
        for (uint256 i = 0; i < bytes(prefix).length; i++) {
            assertEq(bytes(uri)[i], bytes(prefix)[i]);
        }

        bytes memory sliced = slice(bytes(uri), bytes(prefix).length);
        string memory encodedBody = string(sliced);
        bytes memory decoded = Base64.decode(encodedBody);
        string memory json = string(decoded);

        assertTrue(bytes(json).length > 0, "Decoded JSON must not be empty");
        assertTrue(_contains(json, '"name":"'), "Must contain name");
        assertTrue(_contains(json, '"description":"'), "Must contain description");
        assertTrue(_contains(json, '"image": "data:image/svg+xml;base64,'), "Must contain image field");
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

    function slice(bytes memory data, uint256 start) internal pure returns (bytes memory) {
        require(start <= data.length, "slice start too big");
        bytes memory out = new bytes(data.length - start);
        for (uint256 i = 0; i < out.length; i++) {
            out[i] = data[i + start];
        }
        return out;
    }
}