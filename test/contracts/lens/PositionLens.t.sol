// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PositionLens – forge-std test-bench
 * @notice Exercita o cálculo off-chain de taxas pendentes para um NFT de posição.
 */

import "forge-std/Test.sol";
import { NonfungiblePositionManager } from "@evx-periphery/contracts/NonfungiblePositionManager.sol";
import { PositionLens } from "@evx-periphery/contracts/lens/PositionLens.sol";
import { IEvxPool } from "@evx-core/interfaces/IEvxPool.sol";
import '@evx-periphery/libraries/PoolAddress.sol';

/// -----------------------------------------------------------------------
///                               MOCKS
/// -----------------------------------------------------------------------

/**
 * @dev Minimal mock do Position Manager: armazena posições em mapping.
 */
contract MockPositionManager {
    struct Position {
        uint96  nonce;
        address operator;
        address token0;
        address token1;
        uint24  fee;
        int24   tickLower;
        int24   tickUpper;
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    mapping(uint256 => Position) public positions;

    function setPosition(
        uint256 tokenId,
        address token0,
        address token1,
        uint24  fee,
        int24   tickLower,
        int24   tickUpper,
        uint128 liquidity
    ) external {
        positions[tokenId] = Position({
            nonce: 0,
            operator: address(0),
            token0: token0,
            token1: token1,
            fee:    fee,
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidity: liquidity,
            feeGrowthInside0LastX128: 0,
            feeGrowthInside1LastX128: 0,
            tokensOwed0: 0,
            tokensOwed1: 0
        });
    }
}


contract MockEvxPool is IEvxPool {

    struct TickInfo {
        uint128 liquidityGross;
        int128  liquidityNet;
        uint256 feeGrowthOutside0X128;
        uint256 feeGrowthOutside1X128;
        int56   tickCumulativeOutside;
        uint160 secondsPerLiquidityOutsideX128;
        uint32  secondsOutside;
        bool    initialized;
    }

    // slot0
    uint160 private _sqrtPriceX96;
    int24  private _tickCurrent;

    // fee growth global
    uint256 private _fg0;
    uint256 private _fg1;

    // tick map
    mapping(int24 => TickInfo) private _ticks;

    /* setters ----------------------------------------------------------- */

    function setSlot0(int24 tick_) external {
        _tickCurrent = tick_;
    }

    function setFeeGrowthGlobal(uint256 fg0_, uint256 fg1_) external {
        _fg0 = fg0_;
        _fg1 = fg1_;
    }

    function setTick(
        int24   idx,
        uint256 fgOut0,
        uint256 fgOut1
    ) external {
        _ticks[idx].feeGrowthOutside0X128 = fgOut0;
        _ticks[idx].feeGrowthOutside1X128 = fgOut1;
        _ticks[idx].initialized = true;
    }

    /* ---------- Evx pool interface ------------ */

    function slot0()
        external
        view
        returns (
            uint160, int24, uint16, uint16, uint16, uint8, bool
        )
    {
        return (_sqrtPriceX96, _tickCurrent, 0, 0, 0, 0, true);
    }

    function tickBitmap(int16 wordPos) external view override returns (uint256) {}

    function feeGrowthGlobal0X128() external view returns (uint256) { return _fg0; }
    function feeGrowthGlobal1X128() external view returns (uint256) { return _fg1; }

    function ticks(int24 idx)
        external
        view
        returns (
            uint128, int128, uint256, uint256, int56, uint160, uint32, bool
        )
    {
        TickInfo memory t = _ticks[idx];
        return (t.liquidityGross, t.liquidityNet,
                t.feeGrowthOutside0X128, t.feeGrowthOutside1X128,
                t.tickCumulativeOutside, t.secondsPerLiquidityOutsideX128,
                t.secondsOutside, t.initialized);
    }

    /* -------- ABRIDGED: Unused core functions ----- */
    // prettier-ignore
    function observe(uint32[] calldata) external view override returns (int56[] memory, uint160[] memory) {}
    function liquidity() external view override returns (uint128) {}
    function factory() external view override returns (address) {}
    function token0() external view override returns (address) {}
    function token1() external view override returns (address) {}
    function fee() external view override returns (uint24) {}
    function tickSpacing() external pure override returns (int24) {
        return 60;
    }
    function collectProtocol(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1) {}
    function setFeeProtocol(uint8 feeProtocol0, uint8 feeProtocol1) external {}
    function snapshotCumulativesInside(int24 tickLower, int24 tickUpper)
        external
        view
        returns (
            int56 tickCumulativeInside,
            uint160 secondsPerLiquidityInsideX128,
            uint32 secondsInside
        ) {}
    function maxLiquidityPerTick() external view override returns (uint128) {}
    function observations(uint256) external view override returns (uint32, int56, uint160, bool) {}
    function positions(bytes32 key)
        external
        view
        returns (
            uint128 _liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) {}
    function protocolFees() external view override returns (uint128,uint128) {}
    function initializeObservation(uint160 sqrtPriceX96) external override {}
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1) {}

    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1) {}
    function burn(
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1) {}
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {}
    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external {}


    /* ---------- Minimal swap that triggers callback ------------- */
    function swap(
        address /*recipient*/,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 /*sqrtPriceLimitX96*/,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1) {
      return (0, 0);
    }
}

/// -----------------------------------------------------------------------
///                            TEST CONTRACT
/// -----------------------------------------------------------------------

contract PositionLensTest is Test {
    /* ------------------------------------------------------------------ */
    address constant WETH_PLACEHOLDER = address(0xC0FFEE);
    address constant FACTORY          = address(0xFACADE);

    address token0 = address(0xAAA1);
    address token1 = address(0xAAA2);
    uint24  constant FEE = 3_000;

    MockPositionManager pm;
    PositionLens        lens;

    /* ------------------------------------------------------------------ */
    function setUp() public {
        /* 1. mocks */
        pm   = new MockPositionManager();
        lens = new PositionLens(FACTORY, address(pm), WETH_PLACEHOLDER);

        /* 2. endereço “oficial” que o lens espera */
        address poolAddr = PoolAddress.computeAddress(
            FACTORY,
            PoolAddress.PoolKey({ token0: token0, token1: token1, fee: FEE })
        );

        /* 3. deploy qualquer MockEvxPool */
        MockEvxPool impl = new MockEvxPool();

        /* 4. copiar o runtime-code dele para o endereço oficial */
        vm.etch(poolAddr, address(impl).code);

        /* 5. agora podemos configurar a pool chamando o contrato no
              endereço forjado – o código é idêntico ao do mock */
        MockEvxPool pool = MockEvxPool(poolAddr);

        pool.setSlot0(50);
        pool.setFeeGrowthGlobal(100 * 2**128, 40 * 2**128);
        pool.setTick(0,   10 * 2**128, 5  * 2**128);
        pool.setTick(100, 20 * 2**128, 15 * 2**128);

        /* 6. posição NFT */
        pm.setPosition(
            1, token0, token1, FEE,
            0, 100,                       // ticks
            1_000                         // liquidity
        );
    }

    function testFeesInsideRange() public {
        (uint128 owed0, uint128 owed1) = lens.getPositionFee(1);
        assertEq(owed0, 70_000);
        assertEq(owed1, 20_000);
    }

    function testNoVolumeNoFees() public {
        // endereço já calculado no setUp
        address poolAddr = PoolAddress.computeAddress(
            FACTORY,
            PoolAddress.PoolKey({ token0: token0, token1: token1, fee: FEE })
        );
        MockEvxPool pool = MockEvxPool(poolAddr);

        // 1. nenhum volume → todos acumuladores = 0
        pool.setFeeGrowthGlobal(0, 0);
        pool.setTick(0,   0, 0);
        pool.setTick(100, 0, 0);

        // 2. consulta
        (uint128 owed0, uint128 owed1) = lens.getPositionFee(1);

        assertEq(owed0, 0);
        assertEq(owed1, 0);
    }
}