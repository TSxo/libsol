// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/// @title IOwned
///
/// @author TSxo
///
/// @notice The interface for the Owned contract.
interface IOwned {
    // -------------------------------------------------------------------------
    // Events

    /// @notice Emitted when ownership of the contract is transferred.
    ///
    /// @param previousOwner    The address of the previous owner.
    /// @param newOwner         The address of the new owner.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // -------------------------------------------------------------------------
    // Errors

    /// @notice Raised when the caller is not authorized to perform an operation.
    error Owned__Unauthorized();

    /// @notice Raised when constructing the contract with no owner.
    error Owned__ZeroAddress();

    // -------------------------------------------------------------------------
    // Functions

    /// @notice Transfers ownership of the contract to a new account.
    ///
    /// @param newOwner The address of the new owner.
    ///
    /// @dev Requirements:
    /// - Only callable by the owner.
    /// - The new owner must not be the zero address.
    function transferOwnership(address newOwner) external;

    /// @notice Returns the address of the current owner.
    ///
    /// @return result The address of the current owner.
    function owner() external view returns (address result);
}
