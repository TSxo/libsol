// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/// @title IPauseManaged
///
/// @author TSxo
///
/// @notice Interface for the `PauseManaged` contract.
interface IPauseManaged {
    // =========================================================================
    // Events
    // =========================================================================

    /// @notice Emitted when the contract's Pause Authority is updated.
    ///
    /// @param previousAuthority The address of the previous Pause Authority.
    /// @param newAuthority      The address of the new Pause Authority.
    event PauseAuthorityUpdated(address indexed previousAuthority, address indexed newAuthority);

    // =========================================================================
    // Errors
    // =========================================================================

    /// @notice The caller is not the Pause Authority.
    error PauseManaged__Unauthorized();

    /// @notice The Pause Authority reports this contract as paused.
    error PauseManaged__Paused();

    /// @notice The Pause Authority is not a contract, or returned malformed
    /// data from `isPaused`.
    error PauseManaged__InvalidAuthority();

    // =========================================================================
    // Functions
    // =========================================================================

    /// @notice Updates the contract's Pause Authority.
    ///
    /// @param newAuthority The address of the new Pause Authority.
    ///
    /// @dev Requirements:
    /// - Only callable by the current Pause Authority.
    /// - `newAuthority` must be a contract.
    ///
    /// Emits a `PauseAuthorityUpdated` event.
    function setPauseAuthority(address newAuthority) external;

    /// @notice Returns the current Pause Authority.
    ///
    /// @return result The current Pause Authority.
    function pauseAuthority() external view returns (address result);
}
