// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/// @title IPauseAuthority
///
/// @author TSxo
///
/// @notice Defines the core functions required of a Pause Authority.
interface IPauseAuthority {
    // -------------------------------------------------------------------------
    // Events

    /// @notice Emitted when a target contract's Pause Authority is updated.
    ///
    /// @param target       The target contract.
    /// @param newAuthority The address of the new Pause Authority.
    event PauseAuthorityUpdated(address indexed target, address indexed newAuthority);

    // -------------------------------------------------------------------------
    // Functions

    /// @notice Returns whether a target contract is, in any way, paused.
    ///
    /// @param target The target contract.
    ///
    /// @return result True if the target contract is paused, false otherwise.
    function isPaused(address target) external view returns (bool result);

    /// @notice Updates the Pause Authority of the target contract.
    ///
    /// @param target       The target contract.
    /// @param newAuthority The address of the new Authority.
    function setPauseAuthority(address target, address newAuthority) external;
}
