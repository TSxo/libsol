// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { IOwned } from "./IOwned.sol";
import { IOwned2Step } from "./IOwned2Step.sol";
import { Owned } from "./Owned.sol";

/// @title Owned2Step
///
/// @author TSxo
///
/// @notice Single-owner access control where a new owner must accept before
/// ownership moves.
///
/// @dev Extends `Owned`. `transferOwnership` only proposes a new owner, who
/// takes over by calling `acceptOwnership`. A mistyped or unreachable address
/// therefore cannot receive ownership.
///
/// - Proposing again replaces the pending owner.
/// - `transferOwnership(address(0))` cancels a pending transfer; it does not
///   renounce. Use `renounceOwnership` to give up ownership.
/// - Any change of owner clears the pending owner.
///
/// # Upgrade Compatible
///
/// This contract uses ERC-7201 namespaced storage, making it compatible with
/// upgradeable contract architectures.
abstract contract Owned2Step is Owned, IOwned2Step {
    // =========================================================================
    // Type Declarations
    // =========================================================================

    /// @custom:storage-location erc7201:libsol.storage.Owned2Step
    struct Owned2StepStorage {
        address pendingOwner;
    }

    // =========================================================================
    // Constants
    // =========================================================================

    /// @dev keccak256(abi.encode(uint256(keccak256("libsol.storage.Owned2Step")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OWNED_2STEP_SLOT = 0x03d7e960b48153bf789a867f5454db0a88e813e765f551814c2bdaf52ba8db00;

    /// @dev keccak256(bytes("OwnershipTransferStarted(address,address)"))
    bytes32 private constant OWNERSHIP_TRANSFER_STARTED =
        0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700;

    // =========================================================================
    // Functions - Public
    // =========================================================================

    /// @notice Proposes `newOwner` as the next owner. Ownership moves only when
    /// they call `acceptOwnership`.
    ///
    /// @param newOwner The proposed owner, or the zero address to cancel.
    ///
    /// @dev Requirements:
    /// - Only callable by the owner.
    ///
    /// Emits an `OwnershipTransferStarted` event.
    function transferOwnership(address newOwner) public virtual override(IOwned, Owned) onlyOwner {
        assembly ("memory-safe") {
            newOwner := shr(96, shl(96, newOwner))
            sstore(OWNED_2STEP_SLOT, newOwner)
            log3(0x00, 0x00, OWNERSHIP_TRANSFER_STARTED, caller(), newOwner)
        }
    }

    /// @inheritdoc IOwned2Step
    function acceptOwnership() public virtual {
        assembly ("memory-safe") {
            if iszero(eq(caller(), sload(OWNED_2STEP_SLOT))) {
                mstore(0x00, 0x9d0941c9) // `Owned2Step__NotPendingOwner()`
                revert(0x1c, 0x04)
            }
        }

        _transferOwnership(msg.sender);
    }

    /// @inheritdoc IOwned2Step
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /// @inheritdoc IOwned2Step
    function pendingOwner() public view virtual returns (address result) {
        assembly ("memory-safe") {
            result := sload(OWNED_2STEP_SLOT)
        }
    }

    // =========================================================================
    // Functions - Internal
    // =========================================================================

    /// @notice Transfers ownership immediately and clears any pending owner.
    ///
    /// @param newOwner The address of the new owner.
    ///
    /// @dev Internal function with no access control. Also used by
    /// `_initializeOwned`, `acceptOwnership`, and `renounceOwnership`.
    ///
    /// Emits an `OwnershipTransferred` event.
    function _transferOwnership(address newOwner) internal virtual override {
        assembly ("memory-safe") {
            sstore(OWNED_2STEP_SLOT, 0)
        }

        super._transferOwnership(newOwner);
    }
}
