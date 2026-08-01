// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { MockToken } from "./MockToken.sol";

contract CreateTokens is Script {
    function run()
        external
        returns (
            address                            tokenA,
            address                            tokenB
        )
    {
        uint256 deployerKey     = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        // Deploy mock tokens
        tokenA = address(new MockToken("ETH", "ETH"));

        vm.stopBroadcast();

        console.log("DEPLOY_ADDRESS NEW ETH=", tokenA);
    }
}
