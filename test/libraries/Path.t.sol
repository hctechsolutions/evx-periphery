// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { Path } from "@evx-periphery/libraries/Path.sol";
import { BytesLib } from "@evx-periphery/libraries/BytesLib.sol";

/**
 * @title PathTest
 * @notice Unit tests for the Path library (multi‑hop swap encoding helpers).
 */
contract PathTest is Test {
    address internal constant TOKEN0 = 0x1111111111111111111111111111111111111111;
    address internal constant TOKEN1 = 0x2222222222222222222222222222222222222222;
    address internal constant TOKEN2 = 0x3333333333333333333333333333333333333333;

    uint24  internal constant FEE0   = 500;   // 0.05 %
    uint24  internal constant FEE1   = 3_000; // 0.30 %

    // token0 -fee0-> token1
    bytes internal singlePool =
        abi.encodePacked(TOKEN0, FEE0, TOKEN1);

    // token0 -fee0-> token1 -fee1-> token2
    bytes internal multiPool  =
        abi.encodePacked(TOKEN0, FEE0, TOKEN1, FEE1, TOKEN2);

    function testHasMultiplePoolsSingle() external view {
        bool result = Path.hasMultiplePools(singlePool);
        assertFalse(result, "single-pool path reported multiple pools");
    }

    function testHasMultiplePoolsMulti() external view {
        bool result = Path.hasMultiplePools(multiPool);
        assertTrue(result, "multi-pool path not detected");
    }

    function testNumPoolsSingle() external view {
        uint256 n = Path.numPools(singlePool);
        assertEq(n, 1, "numPools(single) != 1");
    }

    function testNumPoolsMulti() external view {
        uint256 n = Path.numPools(multiPool);
        assertEq(n, 2, "numPools(multi) != 2");
    }

    function testDecodeFirstPool() external view {
        (address tokenA, address tokenB, uint24 fee) =
            Path.decodeFirstPool(multiPool);

        assertEq(tokenA, TOKEN0, "tokenA mismatch");
        assertEq(tokenB, TOKEN1, "tokenB mismatch");
        assertEq(fee,    FEE0,   "fee  mismatch");
    }

    function testGetFirstPoolSlice() external view {
        bytes memory first = Path.getFirstPool(multiPool);
        bytes memory expected = abi.encodePacked(TOKEN0, FEE0, TOKEN1);

        assertEq(
            keccak256(first),
            keccak256(expected),
            "first-pool slice incorrect"
        );
    }

   function testSkipTokenMulti() external view {
        bytes memory rest = Path.skipToken(multiPool);
        bytes memory expected = abi.encodePacked(TOKEN1, FEE1, TOKEN2);

        assertEq(
            keccak256(rest),
            keccak256(expected),
            "skipToken output incorrect for multi-pool"
        );
    }

    /**
     * @notice For a single‑pool path, skipping the first token + fee leaves only
     *         the final token address (20 bytes) in the buffer.
     */
    function testSkipTokenSingle() external view {
        bytes memory rest = Path.skipToken(singlePool);
        bytes memory expected = abi.encodePacked(TOKEN1);

        assertEq(
            keccak256(rest),
            keccak256(expected),
            "skipToken output incorrect for single-pool"
        );
    }
}
