// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/// @title IPausedManaged
///
/// @author TSxo
///
/// @notice Interface for the PausedManaged contract.
interface IPauseManaged {
    // -------------------------------------------------------------------------
    // Events

    /// @notice Emitted when the contract's Pause Authority is updated.
    ///
    /// @param previousAuthority The address of the previous Pause Authority.
    /// @param newAuthority      The address of the new Pause Authority.
    event PauseAuthorityUpdated(address indexed previousAuthority, address indexed newAuthority);

    // -------------------------------------------------------------------------
    // Errors

    /// @notice Raised when the caller is not authorized to perform an operation.
    error PauseManaged__Unauthorized();

    /// @notice Raised when a call is made while the contract is paused.
    error PauseManaged__Paused();

    // -------------------------------------------------------------------------
    // Functions

    /// @notice Updates the contract's Pause Authority.
    ///
    /// @param newAuthority The address of the new Pause Authority.
    ///
    /// @dev Requirements:
    /// - Only callable by the current Pause Authority.
    ///
    /// Emits a `PauseAuthorityUpdated` event.
    function setPauseAuthority(address newAuthority) external;

    /// @notice Returns the current Pause Authority.
    ///
    /// @return result The current Pause Authority.
    function pauseAuthority() external view returns (address result);
}
