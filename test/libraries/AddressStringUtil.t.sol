// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-periphery/libraries/AddressStringUtil.sol";


contract AddressStringUtilWrapper {
    using AddressStringUtil for address;

    function toAsciiString(address addr, uint256 len) external pure returns (string memory) {
        return addr.toAsciiString(len);
    }
}

contract AddressStringUtilTest is Test {
    AddressStringUtilWrapper util;

    address constant TEST_ADDRESS = 0x1234567890AbcdEF1234567890aBcdef12345678;

    function setUp() public {
        util = new AddressStringUtilWrapper();
    }

    function testToAsciiStringFull() public view {
        string memory result = util.toAsciiString(TEST_ADDRESS, 40);
        assertEq(result, "1234567890ABCDEF1234567890ABCDEF12345678", "Full address string mismatch");
    }

    function testToAsciiStringPartial() public view {
        string memory result = util.toAsciiString(TEST_ADDRESS, 8);
        assertEq(result, "12345678", "Partial address string mismatch");
    }

    function testToAsciiStringInvalidLengthZero() public {
        vm.expectRevert(bytes("AddressStringUtil: INVALID_LEN"));
        util.toAsciiString(TEST_ADDRESS, 0);
    }

    function testToAsciiStringInvalidLengthOdd() public {
        vm.expectRevert(bytes("AddressStringUtil: INVALID_LEN"));
        util.toAsciiString(TEST_ADDRESS, 7);
    }

    function testToAsciiStringInvalidLengthTooLong() public {
        vm.expectRevert(bytes("AddressStringUtil: INVALID_LEN"));
        util.toAsciiString(TEST_ADDRESS, 42);
    }
}