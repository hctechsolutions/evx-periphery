// SPDX‑License‑Identifier: MIT
pragma solidity ^0.8.20;


import "forge-std/Test.sol";
import {HexStrings} from "@evx-periphery/libraries/HexStrings.sol";

/**
 * @title HexStringsTest
 * @notice Unit‑tests for the HexStrings library (with and without prefix).
 * @dev Minimal wrapper – internal library calls must live inside a contract.
 */
contract HexStringsWrapper {
    function withPrefix(uint256 value, uint256 len) external pure returns (string memory) {
        return HexStrings.toHexString(value, len);
    }

    function noPrefix(uint256 value, uint256 len) external pure returns (string memory) {
        return HexStrings.toHexStringNoPrefix(value, len);
    }
}

contract HexStringsTest is Test {
    HexStringsWrapper internal wrapper;

    function setUp() public {
        wrapper = new HexStringsWrapper();
    }

    /** @notice 0 → "0x00" when length = 1. */
    function testWithPrefixZero() external view {
        string memory expected = "0x00";
        string memory actual   = wrapper.withPrefix(0, 1);
        assertEq(actual, expected);
    }

    /** @notice 0xDEADBEEF → "0xdeadbeef" with length = 4 (8 hex digits). */
    function testWithPrefixRegular() external view {
        string memory expected = "0xdeadbeef";
        string memory actual   = wrapper.withPrefix(0xDEADBEEF, 4);
        assertEq(actual, expected);
    }

    /** @notice Reverts when `length` is too small for the value. */
    function testWithPrefixRevertsOnShortLength() external {
        vm.expectRevert("Strings: hex length insufficient");
        wrapper.withPrefix(0x1234, 1); // needs 2 bytes (length = 2)
    }

    /** @notice 0 → "00" when length = 1 (two hex digits). */
    function testNoPrefixZero() external view {
        string memory expected = "00";
        string memory actual   = wrapper.noPrefix(0, 1);
        assertEq(actual, expected);
    }

    /** @notice 0xABCD → "abcd" with length = 2. */
    function testNoPrefixRegular() external view {
        string memory expected = "abcd";
        string memory actual   = wrapper.noPrefix(0xABCD, 2);
        assertEq(actual, expected);
    }

    /** @notice Largest 256‑bit value returns 64 hex digits. */
    function testNoPrefixMaxUint256() external view {
        string memory expected =
            "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
        string memory actual = wrapper.noPrefix(type(uint256).max, 32);
        assertEq(actual, expected);
    }
}
