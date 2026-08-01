// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import '@evx-periphery/libraries/ChainId.sol';
import '@evx-periphery/interfaces/external/IERC1271.sol';
import '@evx-periphery/interfaces/IERC721Permit.sol';
import './BlockTimestamp.sol';

/**
 * @title ERC721Permit
 * @notice Nonfungible tokens that support approvals via EIP-712 signatures (gasless permits).
 * @dev Supports off-chain approvals, compatible with smart wallets via ERC1271.
 */
abstract contract ERC721Permit is BlockTimestamp, ERC721, IERC721Permit {
    /// @dev Gets the current nonce for a token ID and then increments it, returning the original value
    function _getAndIncrementNonce(uint256 tokenId) internal virtual returns (uint256);

    /// @dev The hash of the name used in the permit signature verification
    bytes32 private immutable nameHash;

    /// @dev The hash of the version string used in the permit signature verification
    bytes32 private immutable versionHash;

    /**
     * @notice Contract constructor that computes EIP-712 domain parameters.
     * @dev Initializes the ERC721 base and caches hashed name and version.
     * @param name_ The name of the ERC721 token.
     * @param symbol_ The symbol of the ERC721 token.
     * @param version_ The version string used in the EIP-712 domain.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        string memory version_
    ) ERC721(name_, symbol_) {
        nameHash = keccak256(bytes(name_));
        versionHash = keccak256(bytes(version_));
    }

    /// @inheritdoc IERC721Permit
    function DOMAIN_SEPARATOR() public view override returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    // keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)')
                    0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                    nameHash,
                    versionHash,
                    ChainId.get(),
                    address(this)
                )
            );
    }

    /**
     * @notice Checks if an address is a contract.
     * @dev Uses code length to detect contract accounts.
     * @param account The address to check.
     * @return True if the address is a contract, false otherwise.
     * TODO: Improve address checking to accept only smart contracts.
     */
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    /// @inheritdoc IERC721Permit
    /// @dev Value is equal to keccak256("Permit(address spender,uint256 tokenId,uint256 nonce,uint256 deadline)");
    bytes32 public constant override PERMIT_TYPEHASH =
        0x49ecf333e5b8c95c40fdafc95c1ad136e8914a8fb55e9dc8bb01eaa83a2df9ad;

    /// @inheritdoc IERC721Permit
    function permit(
        address spender,
        uint256 tokenId,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable override {
        require(_blockTimestamp() <= deadline, "Permit expired");

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH,
                        spender,
                        tokenId,
                        _getAndIncrementNonce(tokenId),
                        deadline
                    )
                )
            )
        );

        address owner = ownerOf(tokenId);
        require(spender != owner, "ERC721Permit: approval to current owner");

        if (isContract(owner)) {
            require(
                IERC1271(owner).isValidSignature(digest, abi.encodePacked(r, s, v)) ==
                    0x1626ba7e,
                "Unauthorized"
            );
        } else {
            address recovered = ecrecover(digest, v, r, s);
            require(recovered != address(0), "Invalid signature");
            require(recovered == owner, "Unauthorized");
        }

        _approve(spender, tokenId, owner);
    }
}
