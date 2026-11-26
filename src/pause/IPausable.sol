// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/// @title IPausable
///
/// @author TSxo
///
/// @notice Interface for the `Pausable` contract.
interface IPausable {
    // =========================================================================
    // Events
    // =========================================================================

    /// @notice Emitted when the contract's pause status has been updated.
    ///
    /// @param caller   The address that updated the status.
    /// @param enabled  Whether the contract was paused.
    event Paused(address indexed caller, bool enabled);

    // =========================================================================
    // Errors
    // =========================================================================

    /// @notice The contract is paused.
    error Pausable__PauseEnforced();

    /// @notice The contract is not paused.
    error Pausable__PauseExpected();

    // =========================================================================
    // Functions
    // =========================================================================

    /// @notice Returns whether the contract is paused.
    ///
    /// @return result True if the contract is paused, false otherwise.
    function isPaused() external view returns (bool result);
}
