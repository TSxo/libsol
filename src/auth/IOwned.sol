// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/// @title IOwned
///
/// @author TSxo
///
/// @notice Interface for the `Owned` contract.
interface IOwned {
    // =========================================================================
    // Events
    // =========================================================================

    /// @notice Emitted when ownership of the contract is transferred.
    ///
    /// @param previousOwner    The address of the previous owner.
    /// @param newOwner         The address of the new owner.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // =========================================================================
    // Errors
    // =========================================================================

    /// @notice The caller is not the owner.
    error Owned__Unauthorized();

    /// @notice The initial owner is the zero address.
    error Owned__ZeroAddress();

    // =========================================================================
    // Functions
    // =========================================================================

    /// @notice Transfers ownership of the contract to a new account.
    ///
    /// @param newOwner The address of the new owner.
    ///
    /// @dev Requirements:
    /// - Only callable by the owner.
    ///
    /// Setting `newOwner` to `address(0)` renounces ownership permanently.
    function transferOwnership(address newOwner) external;

    /// @notice Returns the address of the current owner.
    ///
    /// @return result The address of the current owner.
    function owner() external view returns (address result);
}
