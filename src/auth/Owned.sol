// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IOwned } from "./IOwned.sol";

/// @title Owned
///
/// @author TSxo
///
/// @dev `Owned` is an ERC-173 compliant contract that enables basic access
/// control. A single account is designated the `owner` of the contract. This
/// account can be granted exclusive access to operations within the contract
/// by applying the `onlyOwner` modifier to any functions you wish to restrict.
///
/// The owner is set upon initialization and can be updated with at any stage
/// with `transferOwnership`.
///
/// To renounce ownership, call `transferOwnership(address(0))`.
///
/// # Upgrade Compatible
///
/// This contract utilizes ERC-7201 namespaced storage, making it compatible with
/// upgradeable contract architectures. Note, it does not enforce any restrictions
/// against reinitialization, leaving such protection mechanisms up to the
/// inheriting contract.
///
/// # Acknowledgements
///
/// Heavy inspiration is taken from:
/// - OpenZeppelin;
/// - Solmate; and
/// - Solady.
///
/// Thank you.
abstract contract Owned is IOwned {
    // -------------------------------------------------------------------------
    // Type Declarations

    /// @custom:storage-location erc7201:libsol.storage.Owned
    struct OwnedStorage {
        address owner;
    }

    // -------------------------------------------------------------------------
    // State

    /// @dev keccak256(abi.encode(uint256(keccak256("libsol.storage.Owned")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OWNED_SLOT = 0x004a2de2e3667a1e83d879c80633387ece8ffaa2a60d61bc81eb25bb9337ba00;

    /// @dev keccak256(bytes("OwnershipTransferred(address,address)"))
    bytes32 private constant OWNERSHIP_TRANSFERRED = 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0;

    // -------------------------------------------------------------------------
    // Modifiers

    /// @dev Restricts access to calls only from the owner account.
    modifier onlyOwner() virtual {
        _assertOwner();
        _;
    }

    // -------------------------------------------------------------------------
    // Functions - Init

    /// @notice Initializes the contract by setting the initial owner.
    ///
    /// @param initialOwner The address to be set as the initial owner.
    ///
    /// @dev Requirements:
    /// - The initial owner cannot be the zero address.
    function _initializeOwned(address initialOwner) internal virtual {
        assembly ("memory-safe") {
            if iszero(initialOwner) {
                mstore(0x00, 0xa0750438) // `Owned__ZeroAddress()`
                revert(0x1c, 0x04)
            }
        }

        _transferOwnership(initialOwner);
    }

    // -------------------------------------------------------------------------
    // Functions - Public

    /// @inheritdoc IOwned
    function transferOwnership(address newOwner) public virtual onlyOwner {
        _transferOwnership(newOwner);
    }

    /// @inheritdoc IOwned
    function owner() public view virtual returns (address result) {
        assembly ("memory-safe") {
            result := sload(OWNED_SLOT)
        }
    }

    // -------------------------------------------------------------------------
    // Functions - Internal

    /// @notice Transfers ownership of the contract to a new account.
    ///
    /// @param newOwner The address of the new owner.
    ///
    /// @dev Internal function with no access control or restriction regarding
    /// the address that can be set.
    ///
    /// Emits an `OwnershipTransferred` event.
    function _transferOwnership(address newOwner) internal virtual {
        assembly ("memory-safe") {
            newOwner := shr(96, shl(96, newOwner))
            log3(0x00, 0x00, OWNERSHIP_TRANSFERRED, sload(OWNED_SLOT), newOwner)
            sstore(OWNED_SLOT, newOwner)
        }
    }

    /// @dev Asserts that the caller is the owner of the contract.
    function _assertOwner() internal view virtual {
        assembly ("memory-safe") {
            if iszero(eq(caller(), sload(OWNED_SLOT))) {
                mstore(0x00, 0xaf50ad97) // `Owned__Unauthorized()`
                revert(0x1c, 0x04)
            }
        }
    }
}
