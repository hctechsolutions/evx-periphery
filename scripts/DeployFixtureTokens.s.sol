// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import "forge-std/console.sol";
import { MockToken } from "./MockToken.sol";

/**
 * @title DeployFixtureTokens
 * @notice The same six ERC-20 fixtures on every supported network.
 */
contract DeployFixtureTokens is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerKey);
        console.log("DEPLOY_ADDRESS FET=", address(new MockToken("Fetch.ai", "FET")));
        console.log("DEPLOY_ADDRESS AVAX=", address(new MockToken("Avalanche", "AVAX")));
        console.log("DEPLOY_ADDRESS LINK=", address(new MockToken("Chainlink", "LINK")));
        console.log("DEPLOY_ADDRESS USDC=", address(new MockToken("USD Coin", "USDC")));
        console.log("DEPLOY_ADDRESS DAI=", address(new MockToken("Dai", "DAI")));
        console.log("DEPLOY_ADDRESS UNI=", address(new MockToken("Uniswap", "UNI")));
        vm.stopBroadcast();
    }
}
