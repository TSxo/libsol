// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { IOwned } from "./IOwned.sol";

/// @title IOwned2Step
///
/// @author TSxo
///
/// @notice Interface for the `Owned2Step` contract.
interface IOwned2Step is IOwned {
    // =========================================================================
    // Events
    // =========================================================================

    /// @notice Emitted when the owner proposes a new owner.
    ///
    /// @param previousOwner The current owner.
    /// @param newOwner      The proposed owner, who must accept.
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    // =========================================================================
    // Errors
    // =========================================================================

    /// @notice The caller is not the pending owner.
    error Owned2Step__NotPendingOwner();

    // =========================================================================
    // Functions
    // =========================================================================

    /// @notice Accepts a pending ownership transfer.
    ///
    /// @dev Requirements:
    /// - Only callable by the pending owner.
    ///
    /// Emits an `OwnershipTransferred` event.
    function acceptOwnership() external;

    /// @notice Gives up ownership permanently, leaving the contract without an
    /// owner. Also cancels any pending transfer.
    ///
    /// @dev Requirements:
    /// - Only callable by the owner.
    ///
    /// Emits an `OwnershipTransferred` event.
    function renounceOwnership() external;

    /// @notice Returns the pending owner.
    ///
    /// @return result The pending owner, or the zero address if there is none.
    function pendingOwner() external view returns (address result);
}
