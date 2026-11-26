// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/// @title IPauseAuthority
///
/// @author TSxo
///
/// @notice Interface that every Pause Authority must implement.
interface IPauseAuthority {
    // =========================================================================
    // Events
    // =========================================================================

    /// @notice Emitted when a target contract's Pause Authority is updated.
    ///
    /// @param target       The target contract.
    /// @param newAuthority The address of the new Pause Authority.
    ///
    /// @dev Shares its signature with `IPauseManaged.PauseAuthorityUpdated`,
    /// which the target emits with (previous, new) Authority. Indexers should
    /// tell the two apart by the emitting contract.
    event PauseAuthorityUpdated(address indexed target, address indexed newAuthority);

    // =========================================================================
    // Functions
    // =========================================================================

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
    ///
    /// @dev Requirements:
    /// - `target` must be a contract.
    /// - `newAuthority` must be a contract; the target enforces this.
    function setPauseAuthority(address target, address newAuthority) external;
}
