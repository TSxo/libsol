// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/// @title IAuthManaged
///
/// @author TSxo
///
/// @notice Interface for the `AuthManaged` contract.
interface IAuthManaged {
    // =========================================================================
    // Events
    // =========================================================================

    /// @notice Emitted when the contract's Authority is updated.
    ///
    /// @param previousAuthority The address of the previous Authority.
    /// @param newAuthority      The address of the new Authority.
    event AuthorityUpdated(address indexed previousAuthority, address indexed newAuthority);

    // =========================================================================
    // Errors
    // =========================================================================

    /// @notice The caller is not permitted: the Authority denied the call, or
    /// the caller is not the Authority.
    error AuthManaged__Unauthorized();

    /// @notice The Authority is not a contract, or returned malformed data from
    /// `canCall`.
    error AuthManaged__InvalidAuthority();

    // =========================================================================
    // Functions
    // =========================================================================

    /// @notice Updates the contract's Authority.
    ///
    /// @param newAuthority The address of the new Authority.
    ///
    /// @dev Requirements:
    /// - Only callable by the current Authority.
    /// - `newAuthority` must be a contract.
    ///
    /// Emits an `AuthorityUpdated` event.
    function setAuthority(address newAuthority) external;

    /// @notice Returns the current Authority.
    ///
    /// @return result The current Authority.
    function authority() external view returns (address result);
}
