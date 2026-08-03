// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { EvxFactory } from "@evx-core/contracts/EvxFactory.sol";
import { EvxPool } from "@evx-core/contracts/EvxPool.sol";
import { TickMath } from "@evx-core/libraries/TickMath.sol";

import { NonfungiblePositionManager } from "@evx-periphery/contracts/NonfungiblePositionManager.sol";
import { NonfungibleTokenPositionDescriptor } from "@evx-periphery/contracts/NonfungibleTokenPositionDescriptor.sol";
import { MockToken } from "./MockToken.sol";

/**
 * @title HarnessLocal
 * @notice Deterministic local Anvil deploy: factory + pool + NPM + mock ERC20s (Story 5.3).
 * @dev No Sepolia fork. Seed via `--private-key` / `DEPLOYER_PRIVATE_KEY`.
 *
 * Example:
 *   anvil
 *   DEPLOYER_PRIVATE_KEY=0xac09... forge script scripts/HarnessLocal.s.sol:HarnessLocal \
 *     --rpc-url http://127.0.0.1:8545 --broadcast
 */
contract HarnessLocal is Script {
    uint24 internal constant FEE = 3000;

    function run()
        external
        returns (
            address factoryAddr,
            address npmAddr,
            address poolAddr,
            address token0,
            address token1
        )
    {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        EvxPool impl = new EvxPool();
        EvxFactory factory = new EvxFactory(address(impl));

        MockToken tokenA = new MockToken("HarnessA", "HRA");
        MockToken tokenB = new MockToken("HarnessB", "HRB");
        if (address(tokenA) < address(tokenB)) {
            token0 = address(tokenA);
            token1 = address(tokenB);
        } else {
            token0 = address(tokenB);
            token1 = address(tokenA);
        }

        address weth9 = address(0xC0FFEE);
        NonfungibleTokenPositionDescriptor descriptor =
            new NonfungibleTokenPositionDescriptor(weth9, _strToBytes32("ETH"));
        NonfungiblePositionManager npm =
            new NonfungiblePositionManager(address(factory), weth9, address(descriptor));

        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(0);
        poolAddr = npm.createAndInitializePoolIfNecessary(token0, token1, FEE, sqrtPriceX96);

        vm.stopBroadcast();

        factoryAddr = address(factory);
        npmAddr = address(npm);

        console.log("DEPLOY_ADDRESS FACTORY=", factoryAddr);
        console.log("DEPLOY_ADDRESS POSITION_MANAGER=", npmAddr);
        console.log("DEPLOY_ADDRESS POOL=", poolAddr);
        console.log("DEPLOY_ADDRESS TOKEN0=", token0);
        console.log("DEPLOY_ADDRESS TOKEN1=", token1);
        console.log("DEPLOY_FIXTURE FEE=", uint256(FEE));
        console.log("DEPLOY_FIXTURE SQRT_PRICE_TICK=0");
    }

    function _strToBytes32(string memory s) internal pure returns (bytes32 r) {
        bytes memory temp = bytes(s);
        require(temp.length <= 32, "label");
        assembly {
            r := mload(add(temp, 32))
        }
    }
}
