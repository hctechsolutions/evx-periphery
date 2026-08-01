// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-periphery/contracts/base/ERC721Permit.sol";

/**
 * @title ERC721Permit Test Suite
 * @notice Unit tests for the ERC721Permit abstract contract using a concrete mock implementation.
 * @dev Verifies DOMAIN_SEPARATOR logic and `permit` signature approval flow.
 */
contract ERC721PermitTest is Test {
    MockERC721Permit private nft;
    address private owner;
    uint256 private ownerKey;
    address private spender;
    uint256 private spenderKey;

    // Cached constants
    uint256 private constant TOKEN_ID = 42;
    uint256 private constant DEADLINE_OFFSET = 1 days;

    /**
     * @notice Deploys a fresh mock NFT and prepares test addresses.
     */
    function setUp() public {
        ownerKey = 0xA11CE; // arbitrary private key
        spenderKey = 0xB0B; // arbitrary private key
        owner = vm.addr(ownerKey);
        spender = vm.addr(spenderKey);

        nft = new MockERC721Permit("Evx NFT", "NB-NFT", "1");
        nft.mint(owner, TOKEN_ID);
    }

    /**
     * @notice Ensures the DOMAIN_SEPARATOR encodes the current chain ID and contract address.
     */
    function testDomainSeparator() public view {
        bytes32 ds = nft.DOMAIN_SEPARATOR();

        // Compute expected domain separator off-chain for comparison
        bytes32 expected = keccak256(
            abi.encode(
                0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f, // type hash
                keccak256(bytes("Evx NFT")),
                keccak256(bytes("1")),
                block.chainid,
                address(nft)
            )
        );
        assertEq(ds, expected, "DOMAIN_SEPARATOR mismatch");
    }

    /**
     * @notice Successfully approves `spender` for `TOKEN_ID` using an off‑chain EIP‑712 signature.
     */
    function testPermitSuccess() public {
        uint256 deadline = block.timestamp + DEADLINE_OFFSET;

        // Prepare EIP-712 struct hash
        bytes32 structHash = keccak256(
            abi.encode(
                nft.PERMIT_TYPEHASH(),
                spender,
                TOKEN_ID,
                0, // nonce is 0 for first permit
                deadline
            )
        );

        // Compute digest per EIP‑712 rules
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", nft.DOMAIN_SEPARATOR(), structHash)
        );

        // Sign with owner's key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, digest);

        // Call permit from any actor (spender in this case)
        vm.prank(spender);
        nft.permit(spender, TOKEN_ID, deadline, v, r, s);

        // Validate approval
        assertEq(nft.getApproved(TOKEN_ID), spender, "Permit should approve spender");

        // Nonce should increment
        assertEq(nft.nonces(TOKEN_ID), 1, "Nonce should increment after permit");
    }

    /**
     * @notice Reverts when signature is expired.
     */
    function testPermitExpired() public {
        uint256 deadline = block.timestamp + 1; // 1 second ahead

        // Advance time beyond deadline
        vm.warp(block.timestamp + 2);

        bytes32 structHash = keccak256(
            abi.encode(
                nft.PERMIT_TYPEHASH(),
                spender,
                TOKEN_ID,
                0,
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", nft.DOMAIN_SEPARATOR(), structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, digest);

        vm.prank(spender);
        vm.expectRevert("Permit expired");
        nft.permit(spender, TOKEN_ID, deadline, v, r, s);
    }
}

/**
 * @title Mock ERC721Permit
 * @notice Minimal concrete implementation of ERC721Permit for testing.
 */
contract MockERC721Permit is ERC721Permit {
    /**
     * @dev Tracks nonces per token ID.
     */
    mapping(uint256 => uint256) private _nonces;

    /**
     * @notice Initializes the mock NFT.
     * @param name_   ERC‑721 token name.
     * @param symbol_ ERC‑721 token symbol.
     * @param version_ Version string for EIP‑712 domain.
     */
    constructor(string memory name_, string memory symbol_, string memory version_)
        ERC721Permit(name_, symbol_, version_)
    {}

    /**
     * @notice Mints a new token ID to the specified address.
     * @param to      Recipient address.
     * @param tokenId Token ID to mint.
     */
    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    /**
     * @inheritdoc ERC721Permit
     */
    function _getAndIncrementNonce(uint256 tokenId) internal override returns (uint256) {
        return _nonces[tokenId]++;
    }

    /**
     * @notice Exposes nonce for assertions.
     * @param tokenId Token ID queried.
     * @return Current nonce value.
     */
    function nonces(uint256 tokenId) external view returns (uint256) {
        return _nonces[tokenId];
    }
}
