// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IMulticall
 * @notice Interface for batching multiple contract calls into a single external call.
 * @dev Commonly used to reduce gas costs and latency for read and write operations.
 */
interface IMulticall {
    /**
     * @notice Executes multiple calls to the current contract in a single transaction.
     * @dev All calls are executed via `delegatecall`. If any call fails, the entire multicall reverts.
     * Do not rely on `msg.value` inside called functions, as it reflects the full value sent to `multicall`.
     *
     * @param data An array of encoded function calls to execute sequentially.
     * @return results An array of return data from each successful call.
     */
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);
}
