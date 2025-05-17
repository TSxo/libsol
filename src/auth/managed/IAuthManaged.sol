// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/// @title IAuthManaged
///
/// @author TSxo
///
/// @notice Interface for the AuthManaged contract.
interface IAuthManaged {
    // -------------------------------------------------------------------------
    // Events

    /// @notice Emitted when the contract's Authority is updated.
    ///
    /// @param previousAuthority The address of the previous Authority.
    /// @param newAuthority      The address of the new Authority.
    event AuthorityUpdated(address indexed previousAuthority, address indexed newAuthority);

    // -------------------------------------------------------------------------
    // Errors

    /// @notice Raised when the caller is not authorized to perform an operation.
    error AuthManaged__Unauthorized();

    // -------------------------------------------------------------------------
    // Functions

    /// @notice Updates the contract's Authority.
    ///
    /// @param newAuthority The address of the new Authority.
    ///
    /// @dev Requirements:
    /// - Only callable by the current Authority.
    ///
    /// Emits an `AuthorityUpdated` event.
    function setAuthority(address newAuthority) external;

    /// @notice Returns the current Authority.
    ///
    /// @return result The current Authority.
    function authority() external view returns (address result);
}
