// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BytesLibTest
 * @notice Unit‑tests for the BytesLib library (slice, toAddress and toUint24).
 * @dev Uses Forge StdLib.  Run with `forge test -vv`.
 */
import "forge-std/Test.sol";
import { BytesLib } from "@evx-periphery/libraries/BytesLib.sol";

contract BytesLibTest is Test {
    /// @dev A 64‑byte array with predictable values (0x00, 0x01, 0x02 …).
    bytes internal constant SAMPLE =
        hex"000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
            hex"202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f";

    /// @dev Now checksummed, so the compiler is happy.
    address internal constant SOME_ADDRESS = 0x111122223333444455556666777788889999aAaa;
    uint24  internal constant SOME_UINT24  = 0xA1B2C3;

    /* -------------------------------------------------------------------------- */
    /*                               ~~~  slice  ~~~                              */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Slice the full array and expect the same bytes back.
     */
    function testSliceFull() external pure {
        bytes memory result = BytesLib.slice(SAMPLE, 0, SAMPLE.length);
        assertEq(keccak256(result), keccak256(SAMPLE), "full slice differs");
    }

    /**
     * @notice Slice a sub‑range in the middle of the array.
     * @dev [16, 32) should return exactly 16 bytes (0x10 … 0x1F).
     */
    function testSlicePartial() external pure {
        bytes memory expected =
            hex"101112131415161718191a1b1c1d1e1f";
        bytes memory result   = BytesLib.slice(SAMPLE, 16, 16);
        assertEq(keccak256(result), keccak256(expected), "partial slice failed");
    }

    /**
     * @notice Zero‑length slice MUST return an empty array.
     */
    function testSliceZeroLength() external pure {
        bytes memory result = BytesLib.slice(SAMPLE, 10, 0);
        assertEq(result.length, 0, "zero length slice not empty");
    }

    /**
     * @notice Out‑of‑bounds slice MUST revert with `slice_outOfBounds`.
     * forge-config: default.allow_internal_expect_revert = true
     */
    function testSliceOutOfBoundsReverts() external {
        vm.expectRevert("slice_outOfBounds");
        BytesLib.slice(SAMPLE, 60, 8); // 60 + 8 > 64
    }

    /* -------------------------------------------------------------------------- */
    /*                              ~~~  toAddress  ~~~                           */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Convert bytes to an address and expect exact match.
     */
    function testToAddress() external pure {
        // Build bytes = <32‑byte prefix><20‑byte address><12‑byte suffix>
        bytes memory data = abi.encodePacked(
            bytes12(0xDEADBEEFCAFEBABE00000000),
            SOME_ADDRESS,
            bytes12(0xFEEDFACE0000000000000000)
        );
        address extracted = BytesLib.toAddress(data, 12); // skip the 12‑byte prefix
        assertEq(extracted, SOME_ADDRESS, "address mismatch");
    }

    /**
     * @notice Out‑of‑bounds toAddress MUST revert with `toAddress_outOfBounds`.
     * forge-config: default.allow_internal_expect_revert = true
     */
    function testToAddressOutOfBoundsReverts() external {
        vm.expectRevert("toAddress_outOfBounds");
        BytesLib.toAddress(hex"1234", 0); // only 2 bytes
    }

    /* -------------------------------------------------------------------------- */
    /*                              ~~~  toUint24  ~~~                            */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Convert bytes to uint24 and verify value.
     */
    function testToUint24() external pure {
        bytes memory data = abi.encodePacked(
            bytes10(0),              // 10‑byte prefix
            SOME_UINT24              // 3‑byte int
        );
        uint24 extracted = BytesLib.toUint24(data, 10);
        assertEq(extracted, SOME_UINT24, "uint24 mismatch");
    }

    /**
     * @notice Out‑of‑bounds toUint24 MUST revert with `toUint24_outOfBounds`.
     * forge-config: default.allow_internal_expect_revert = true
     */
    function testToUint24OutOfBoundsReverts() external {
        vm.expectRevert("toUint24_outOfBounds");
        BytesLib.toUint24(hex"ABCD", 1); // need 3 bytes starting at 1 but only 3‑1 = 2 remain
    }
}
