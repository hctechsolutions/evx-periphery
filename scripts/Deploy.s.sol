// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { NonfungibleTokenPositionDescriptor } from "@evx-periphery/contracts/NonfungibleTokenPositionDescriptor.sol";
import { NonfungiblePositionManager } from "@evx-periphery/contracts/NonfungiblePositionManager.sol";
import { ISwapRouter } from "@evx-periphery/interfaces/ISwapRouter.sol";
import { TickLens } from "@evx-periphery/contracts/lens/TickLens.sol";
import { SwapRouter } from "@evx-periphery/contracts/SwapRouter.sol";
import { PairFlash } from "@evx-periphery/contracts/PairFlash.sol";
import "@evx-periphery/contracts/lens/PositionLens.sol";
import "@evx-periphery/contracts/lens/Quoter.sol";
import { Script } from "forge-std/Script.sol";
import { MockToken } from "./MockToken.sol";
import "forge-std/console.sol";


/**
 * @title DeployPeriphery
 * @notice One-shot script to deploy Evx periphery contracts + mock tokens.
 */
contract DeployPeriphery is Script {
    /// @dev Helper: converts a short ASCII string to a left-aligned bytes32.
    function _strToBytes32(string memory s) internal pure returns (bytes32 r) {
        bytes memory temp = bytes(s);
        require(temp.length <= 32, "Label too long");
        assembly {
            r := mload(add(temp, 32))
        }
    }

    function run()
        external
        returns (
            NonfungibleTokenPositionDescriptor descriptor,
            NonfungiblePositionManager         positionManager,
            SwapRouter                         swapRouter,
            PairFlash                          pairFlash,
            Quoter                             quoter,
            PositionLens                       positionLens,
            TickLens                           tickLens,
            address                            tokenA,
            address                            tokenB
        )
    {
        uint256 deployerKey     = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address factory         = vm.envAddress("FACTORY_ADDRESS");
        address weth9           = vm.envAddress("WETH9_ADDRESS");
        string memory labelStr  = vm.envOr("NATIVE_LABEL", string("ETH"));
        bytes32 labelBytes      = _strToBytes32(labelStr);

        vm.startBroadcast(deployerKey);

        // Deploy mock tokens
        tokenA = address(new MockToken("FET", "FET"));
        tokenB = address(new MockToken("AVAX", "AVAX"));

        descriptor = new NonfungibleTokenPositionDescriptor(
            weth9,
            labelBytes
        );

        positionManager = new NonfungiblePositionManager(
            factory,
            weth9,
            address(descriptor)
        );

        swapRouter = new SwapRouter(
            factory,
            weth9
        );

        pairFlash = new PairFlash(
            ISwapRouter(address(swapRouter)),
            factory,
            weth9
        );

        quoter = new Quoter(factory, weth9);

        positionLens = new PositionLens(factory, address(positionManager), weth9);

        tickLens = new TickLens();

        vm.stopBroadcast();

        // Log para o script de deploy capturar e gerar resumo
        console.log("DEPLOY_ADDRESS DESCRIPTOR=", address(descriptor));
        console.log("DEPLOY_ADDRESS POSITION_MANAGER=", address(positionManager));
        console.log("DEPLOY_ADDRESS SWAP_ROUTER=", address(swapRouter));
        console.log("DEPLOY_ADDRESS PAIR_FLASH=", address(pairFlash));
        console.log("DEPLOY_ADDRESS QUOTER=", address(quoter));
        console.log("DEPLOY_ADDRESS POSITION_LENS=", address(positionLens));
        console.log("DEPLOY_ADDRESS TICK_LENS=", address(tickLens));
        console.log("DEPLOY_ADDRESS TOKEN_A_FET=", tokenA);
        console.log("DEPLOY_ADDRESS TOKEN_B_AVAX=", tokenB);
    }
}
