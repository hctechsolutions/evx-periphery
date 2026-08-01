// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title EvxInterfaceMulticall
 * @notice A fork of Multicall2 tailored for the Evx interface with gas tracking and utility functions.
 * @dev Allows batching multiple calls in a single transaction, with per-call gas limits and result metadata.
 */
contract EvxInterfaceMulticall {
    /**
     * @notice Struct representing a call to be made.
     * @param target The contract address to call.
     * @param gasLimit The maximum gas allowed for the call.
     * @param callData The calldata to be sent to the target.
     */
    struct Call {
        address target;
        uint256 gasLimit;
        bytes callData;
    }

    /**
     * @notice Struct representing the result of a call.
     * @param success Indicates if the call was successful.
     * @param gasUsed The amount of gas used by the call.
     * @param returnData The returned data from the call.
     */
    struct Result {
        bool success;
        uint256 gasUsed;
        bytes returnData;
    }

    /**
     * @notice Returns the current block timestamp.
     * @return timestamp The current block timestamp.
     */
    function getCurrentBlockTimestamp() public view returns (uint256 timestamp) {
        timestamp = block.timestamp;
    }

    /**
     * @notice Returns the ETH balance of an address.
     * @param addr The address to check.
     * @return balance The ETH balance of the address.
     */
    function getEthBalance(address addr) public view returns (uint256 balance) {
        balance = addr.balance;
    }

    /**
     * @notice Executes multiple function calls in a single transaction.
     * @dev Each call can have a specified gas limit and its success and return data are captured.
     * @param calls The array of calls to execute.
     * @return blockNumber The block number at which the calls were executed.
     * @return returnData The array of results for each call.
     */
    function multicall(Call[] memory calls) public returns (uint256 blockNumber, Result[] memory returnData) {
        blockNumber = block.number;
        returnData = new Result[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (address target, uint256 gasLimit, bytes memory callData) =
                (calls[i].target, calls[i].gasLimit, calls[i].callData);
            uint256 gasLeftBefore = gasleft();
            (bool success, bytes memory ret) = target.call{gas: gasLimit}(callData);
            uint256 gasUsed = gasLeftBefore - gasleft();
            returnData[i] = Result(success, gasUsed, ret);
        }
    }
}
