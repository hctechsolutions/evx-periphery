// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-core/contracts/EvxFactory.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import "@evx-core/libraries/Errors.sol";

/// @title MockERC20
/// @notice Mock ERC20 token used for testing purposes.
contract MockERC20 is ERC20 {
    /// @notice Mints initial supply to deployer.
    /// @param name Name of the ERC20 token.
    /// @param symbol Symbol of the ERC20 token.
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1e24);
    }
}

/// @title MockPoolImplementation
/// @notice Mock pool implementation that stores initialization parameters for testing.
contract MockPoolImplementation {
    address public lastFactory;
    address public lastToken0;
    address public lastToken1;
    uint24 public lastFee;
    int24 public lastTickSpacing;

    /// @notice Initializes the mock pool with provided parameters.
    /// @param factory_ Address of the factory.
    /// @param token0_ Address of token0.
    /// @param token1_ Address of token1.
    /// @param fee_ Fee tier.
    /// @param tickSpacing_ Tick spacing.
    function initialize(
        address factory_,
        address token0_,
        address token1_,
        uint24 fee_,
        int24 tickSpacing_
    ) external {
        lastFactory = factory_;
        lastToken0 = token0_;
        lastToken1 = token1_;
        lastFee = fee_;
        lastTickSpacing = tickSpacing_;
    }
}

/// @title DelegateCall
/// @notice Contract to simulate delegatecall and verify delegatecall protection.
contract DelegateCall {
    /// @notice Calls `createPool` via delegatecall to a factory address.
    /// @param factory_ Address of the factory.
    /// @param tokenA_ Address of token A.
    /// @param tokenB_ Address of token B.
    /// @param fee_ Fee tier.
    /// @return pool Address of the created pool.
    function callCreatePool(
        address factory_,
        address tokenA_,
        address tokenB_,
        uint24 fee_
    ) external returns (address pool) {
        (bool success, bytes memory data) = factory_.delegatecall(
            abi.encodeWithSelector(
                EvxFactory.createPool.selector,
                tokenA_,
                tokenB_,
                fee_
            )
        );
        if (!success) {
            assembly {
                revert(add(data, 0x20), mload(data))
            }
        }
        pool = abi.decode(data, (address));
    }
}

/// @title EvxFactoryTest
/// @notice Unit tests for EvxFactory contract using Foundry.
contract EvxFactoryTest is Test {
    EvxFactory public factory;
    address public owner;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    MockPoolImplementation public poolImpl;

    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event FeeAmountEnabled(uint24 indexed fee, int24 indexed tickSpacing);
    event PoolCreated(address indexed token0, address indexed token1, uint24 indexed fee, int24 tickSpacing, address pool);

    /// @notice Sets up the initial test environment.
    function setUp() public {
        poolImpl = new MockPoolImplementation();
        factory = new EvxFactory(address(poolImpl));
        owner = address(this);
        tokenA = new MockERC20("TokenA", "TKA");
        tokenB = new MockERC20("TokenB", "TKB");
    }

    /// @notice Tests constructor initialization.
    function testConstructorSetsOwnerAndFees() public view {
        assertEq(factory.owner(), owner);
        assertEq(factory.feeAmountTickSpacing(500), 10);
        assertEq(factory.feeAmountTickSpacing(3000), 60);
        assertEq(factory.feeAmountTickSpacing(10000), 200);
    }

    function testPredictsCorrectPoolAddress() public {
        uint24 fee = 500;

        (address token0, address token1) = address(tokenA) < address(tokenB)
            ? (address(tokenA), address(tokenB))
            : (address(tokenB), address(tokenA));

        bytes32 salt = keccak256(abi.encodePacked(token0, token1, fee));
        address predicted = Clones.predictDeterministicAddress(
            address(poolImpl),
            salt,
            address(factory)
        );

        address pool = factory.createPool(address(tokenA), address(tokenB), fee);
        assertEq(pool, predicted, "Deployed address should match predicted CREATE2 address");
    }

    /// @notice Tests successful pool creation.
    function testCreatePoolSuccess() public {
        uint24 fee = 500;
        address pool = factory.createPool(address(tokenA), address(tokenB), fee);
        (address token0, address token1) = address(tokenA) < address(tokenB)
            ? (address(tokenA), address(tokenB))
            : (address(tokenB), address(tokenA));

        // Verify factory mapping
        assertEq(factory.getPool(token0, token1, fee), pool);
        assertEq(factory.getPool(token1, token0, fee), pool);

        // Verify stub initialize parameters
        MockPoolImplementation cloned = MockPoolImplementation(pool);
        assertEq(cloned.lastFactory(), address(factory));
        assertEq(cloned.lastToken0(), token0);
        assertEq(cloned.lastToken1(), token1);
        assertEq(cloned.lastFee(), fee);
        assertEq(cloned.lastTickSpacing(), int24(factory.feeAmountTickSpacing(fee)));
    }

    /// @notice Tests that creating a pool with identical tokens reverts.
    function testCreatePoolRevertsForSameToken() public {
        vm.expectRevert(abi.encodeWithSelector(IdenticalAddresses.selector));
        factory.createPool(address(tokenA), address(tokenA), 500);
    }

    /// @notice Tests that creating a pool with zero address reverts.
    function testCreatePoolRevertsForZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        factory.createPool(address(0), address(tokenB), 500);
    }

    /// @notice Tests that creating a pool with an unknown fee tier reverts.
    function testCreatePoolRevertsForUnknownFee() public {
        vm.expectRevert(abi.encodeWithSelector(InvalidFee.selector));
        factory.createPool(address(tokenA), address(tokenB), 999);
    }

    /// @notice Tests that creating a duplicate pool reverts.
    function testCreatePoolRevertsForDuplicatePool() public {
        uint24 fee = 500;
        factory.createPool(address(tokenA), address(tokenB), fee);
        vm.expectRevert(abi.encodeWithSelector(PoolExists.selector));
        factory.createPool(address(tokenA), address(tokenB), fee);
    }

    /// @notice Tests that `PoolCreated` event is emitted correctly.
    function testCreatePoolEmitsEvent() public {
        uint24 fee = 500;
        (address token0, address token1) = address(tokenA) < address(tokenB)
            ? (address(tokenA), address(tokenB))
            : (address(tokenB), address(tokenA));
        vm.expectEmit(true, true, true, false);
        emit PoolCreated(token0, token1, fee, int24(factory.feeAmountTickSpacing(fee)), address(0));
        factory.createPool(address(tokenA), address(tokenB), fee);
    }

    /// @notice Tests pool creation ordering.
    function testCreatePoolOrdering() public {
        uint24 fee = 500;
        address a = address(tokenA);
        address b = address(tokenB);
        (address tokenLow, address tokenHigh) = a < b ? (a, b) : (b, a);
        address pool = factory.createPool(tokenHigh, tokenLow, fee);
        assertEq(factory.getPool(tokenLow, tokenHigh, fee), pool);
    }

    /// @notice Tests successful owner update.
    function testSetOwnerSuccess() public {
        address newOwner = address(0x123);
        vm.expectEmit(true, true, false, true);
        emit OwnerChanged(owner, newOwner);
        factory.setOwner(newOwner);
        assertEq(factory.owner(), newOwner);
    }

    /// @notice Tests that only owner can set new owner.
    function testSetOwnerRevertsForNonOwner() public {
        vm.prank(address(0x456));
        vm.expectRevert(abi.encodeWithSelector(Forbidden.selector));
        factory.setOwner(address(0x789));
    }

    /// @notice Tests ownership chaining and permissioning.
    function testSetOwnerChain() public {
        address newOwner = address(0xABC);
        factory.setOwner(newOwner);

        // Old owner no longer able to set
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Forbidden.selector));
        factory.setOwner(address(0xDEF));
        
        // New owner can set again
        vm.prank(newOwner);
        vm.expectEmit(true, true, false, true);
        emit OwnerChanged(newOwner, address(0xDEF));
        factory.setOwner(address(0xDEF));
        assertEq(factory.owner(), address(0xDEF));
    }

    /// @notice Tests enabling a new fee tier successfully.
    function testEnableFeeAmountSuccess() public {
        uint24 fee = 1000;
        int24 spacing = 20;
        vm.expectEmit(true, true, false, true);
        emit FeeAmountEnabled(fee, spacing);
        factory.enableFeeAmount(fee, spacing);
        assertEq(factory.feeAmountTickSpacing(fee), spacing);
    }

    /// @notice Tests enabling edge values for fees and spacing.
    function testEnableFeeAmountEdgeValues() public {
        uint24 feeMin = 1;
        int24 spaceMin = 1;
        vm.expectEmit(true, true, false, true);
        emit FeeAmountEnabled(feeMin, spaceMin);
        factory.enableFeeAmount(feeMin, spaceMin);
        assertEq(factory.feeAmountTickSpacing(feeMin), spaceMin);

        uint24 feeMax = 999999;
        int24 spaceMax = 16383;
        vm.expectEmit(true, true, false, true);
        emit FeeAmountEnabled(feeMax, spaceMax);
        factory.enableFeeAmount(feeMax, spaceMax);
        assertEq(factory.feeAmountTickSpacing(feeMax), spaceMax);
    }

    /// @notice Tests that only the owner can enable new fee tiers.
    function testEnableFeeAmountRevertsForNonOwner() public {
        vm.prank(address(0x456));
        vm.expectRevert(abi.encodeWithSelector(Forbidden.selector));
        factory.enableFeeAmount(2000, 40);
    }

    /// @notice Tests enabling a fee tier with an invalid fee.
    function testEnableFeeAmountRevertsForInvalidFee() public {
        vm.expectRevert(abi.encodeWithSelector(FeeTooHigh.selector));
        factory.enableFeeAmount(1_000_000, 10);
    }

    /// @notice Tests enabling a fee tier with invalid tick spacing values.
    function testEnableFeeAmountRevertsForInvalidTickSpacing() public {
        vm.expectRevert(abi.encodeWithSelector(InvalidTickSpacing.selector));
        factory.enableFeeAmount(2000, 0);
        vm.expectRevert(abi.encodeWithSelector(InvalidTickSpacing.selector));
        factory.enableFeeAmount(2000, 16_384);
    }

    /// @notice Tests re-enabling an already enabled fee tier reverts.
    function testEnableFeeAmountRevertsForDuplicateFee() public {
        vm.expectRevert(abi.encodeWithSelector(AlreadyEnabled.selector));
        factory.enableFeeAmount(500, 15);
    }

    /// @notice Tests that createPool via delegatecall reverts.
    function testNoDelegateCallCreatePool() public {
        DelegateCall dc = new DelegateCall();
        vm.expectRevert(abi.encodeWithSelector(NoDelegateCallError.selector));
        dc.callCreatePool(address(factory), address(tokenA), address(tokenB), 500);
    }
}
