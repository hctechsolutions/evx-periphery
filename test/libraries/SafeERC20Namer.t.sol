// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-periphery/libraries/SafeERC20Namer.sol";

contract ERC20Mock {
    function name() external pure returns (string memory) {
        return "Mock Token";
    }

    function symbol() external pure returns (string memory) {
        return "MTK";
    }
}

contract ERC20Bytes32Mock {
    function name() external pure returns (bytes32) {
        return bytes32("Bytes32 Token");
    }

    function symbol() external pure returns (bytes32) {
        return bytes32("B32");
    }
}

contract ERC20EmptyMock {
    // no name or symbol methods
}

contract SafeERC20NamerWrapper {
    function tokenName(address token) external view returns (string memory) {
        return SafeERC20Namer.tokenName(token);
    }

    function tokenSymbol(address token) external view returns (string memory) {
        return SafeERC20Namer.tokenSymbol(token);
    }
}

contract SafeERC20NamerTest is Test {
    SafeERC20NamerWrapper namer;

    function setUp() public {
        namer = new SafeERC20NamerWrapper();
    }

    function testTokenNameWithString() public {
        ERC20Mock token = new ERC20Mock();
        string memory name = namer.tokenName(address(token));
        assertEq(name, "Mock Token", "Token name should match string implementation");
    }

    function testTokenSymbolWithString() public {
        ERC20Mock token = new ERC20Mock();
        string memory symbol = namer.tokenSymbol(address(token));
        assertEq(symbol, "MTK", "Token symbol should match string implementation");
    }

    function testTokenNameWithBytes32() public {
        ERC20Bytes32Mock token = new ERC20Bytes32Mock();
        string memory name = namer.tokenName(address(token));
        assertEq(name, "Bytes32 Token", "Token name should match bytes32 implementation");
    }

    function testTokenSymbolWithBytes32() public {
        ERC20Bytes32Mock token = new ERC20Bytes32Mock();
        string memory symbol = namer.tokenSymbol(address(token));
        assertEq(symbol, "B32", "Token symbol should match bytes32 implementation");
    }

    function testFallbackTokenNameLength() public {
        ERC20EmptyMock token = new ERC20EmptyMock();
        string memory name = namer.tokenName(address(token));
        assertNotEq("000000000000000000000000000000000000", name);
        assertEq(
            bytes(name).length,
            40,
            "Fallback name deve ter exatamente 40 caracteres hex"
        );
    }

    function testFallbackTokenSymbol() public {
        ERC20EmptyMock token = new ERC20EmptyMock();
        string memory symbol = namer.tokenSymbol(address(token));
        assertNotEq("000000", symbol);
        assertEq(
            bytes(symbol).length,
            6,
            "Fallback symbol should be first 6 chars of hex address"
        );
    }
}
