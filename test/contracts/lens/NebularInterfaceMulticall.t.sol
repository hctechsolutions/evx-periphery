// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-periphery/contracts/lens/EvxInterfaceMulticall.sol";


contract EvxInterfaceMulticallTest is Test {
    EvxInterfaceMulticall multicall;

    address constant TARGET = address(0x1234);

    function setUp() public {
        multicall = new EvxInterfaceMulticall();
    }

    function testGetCurrentBlockTimestamp() public view {
        uint256 timestamp = multicall.getCurrentBlockTimestamp();
        assertEq(timestamp, block.timestamp, "Timestamp should match current block timestamp");
    }

    function testGetEthBalance() public view {
        address addr = address(this);
        uint256 balance = multicall.getEthBalance(addr);
        assertEq(balance, addr.balance, "Balance should match address balance");
    }

    function testMulticall() public {
        EvxInterfaceMulticall.Call[] memory calls = new EvxInterfaceMulticall.Call[](2);

        calls[0] = EvxInterfaceMulticall.Call({
            target: address(multicall),
            gasLimit: 100000,
            callData: abi.encodeWithSelector(multicall.getCurrentBlockTimestamp.selector)
        });

        calls[1] = EvxInterfaceMulticall.Call({
            target: address(multicall),
            gasLimit: 100000,
            callData: abi.encodeWithSelector(multicall.getEthBalance.selector, address(this))
        });

        (uint256 blockNumber, EvxInterfaceMulticall.Result[] memory results) = multicall.multicall(calls);

        assertEq(blockNumber, block.number, "Block number should match current block number");
        assertEq(results.length, 2, "Results length should be 2");

        // Check first call result
        assertTrue(results[0].success, "First call should succeed");
        uint256 returnedTimestamp = abi.decode(results[0].returnData, (uint256));
        assertEq(returnedTimestamp, block.timestamp, "Returned timestamp should match current block timestamp");

        // Check second call result
        assertTrue(results[1].success, "Second call should succeed");
        uint256 returnedBalance = abi.decode(results[1].returnData, (uint256));
        assertEq(returnedBalance, address(this).balance, "Returned balance should match address balance");

        assertGt(results[0].gasUsed, 0, "First call should have used some gas");
        assertGt(results[1].gasUsed, 0, "Second call should have used some gas");
    }
}