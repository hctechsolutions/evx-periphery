// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { EvxFactory } from "@evx-core/contracts/EvxFactory.sol";
import { EvxPool } from "@evx-core/contracts/EvxPool.sol";

import { Script } from "forge-std/Script.sol";
import "forge-std/console.sol";

/**
 * @title Deploy
 * @notice Comprehensive deployment script for the Evx core
 */
contract DeployV1 is Script {
    uint256 private deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

    address public DEPLOYER_WALLET = vm.addr(deployerPrivateKey);
    address public DAO_ADDRESS =  vm.envAddress("DAO_ADDRESS");

    function run() external {
        console.log("Deploying from", msg.sender);
        vm.startBroadcast(deployerPrivateKey);

        EvxPool poolImplementation = new EvxPool();
        console.log("EvxPool implementation deployed at:", address(poolImplementation));

        EvxFactory factory = new EvxFactory(address(poolImplementation));
        console.log("Factory deployed at:", address(factory));

        factory.setOwner(DAO_ADDRESS);
        console.log("Evx factory transferred to DAO");

        console.log("======== DEPLOYMENT ENVIRONMENT ========");
        console.log(string.concat("EVX_FACTORY_ADDR=", vm.toString(address(factory))));
        console.log(string.concat("EVX_POOL_IMPLEMENTATION=", vm.toString(address(poolImplementation))));
        console.log("===================================");

        vm.stopBroadcast();
    }
}