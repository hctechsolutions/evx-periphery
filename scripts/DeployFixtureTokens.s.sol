// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import "forge-std/console.sol";
import { MockToken } from "./MockToken.sol";

/**
 * @title DeployFixtureTokens
 * @notice Anvil-only ERC20 fixtures. Not part of a public-network deploy.
 */
contract DeployFixtureTokens is Script {
    function run() external returns (address tokenA, address tokenB) {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerKey);
        tokenA = address(new MockToken("FET", "FET"));
        tokenB = address(new MockToken("AVAX", "AVAX"));
        vm.stopBroadcast();
        console.log("DEPLOY_ADDRESS TOKEN_A_FET=", tokenA);
        console.log("DEPLOY_ADDRESS TOKEN_B_AVAX=", tokenB);
    }
}
