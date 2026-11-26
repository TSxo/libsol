// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/// @title IPauseManager
///
/// @author TSxo
///
/// @notice Interface for the `PauseManager` contract.
interface IPauseManager {
    // =========================================================================
    // Events
    // =========================================================================

    /// @notice Emitted when a target contract's paused status is updated.
    ///
    /// @param target   The target contract.
    /// @param enabled  Whether the target was paused.
    event TargetStatusUpdated(address indexed target, bool enabled);

    /// @notice Emitted when the global pause status is updated.
    ///
    /// @param enabled Whether the global pause was enabled.
    event GlobalStatusUpdated(bool enabled);

    // =========================================================================
    // Errors
    // =========================================================================

    /// @notice The target is not a contract, or returned data from
    /// `setPauseAuthority`.
    error PauseManager__InvalidTarget();

    // =========================================================================
    // Functions
    // =========================================================================

    /// @notice Sets the paused status of a target contract.
    ///
    /// @param target   The address of the target contract.
    /// @param enabled  Whether to pause the target contract.
    ///
    /// @dev Requirements:
    /// - Only callable by an account `_authorizeManager` accepts.
    ///
    /// Emits a `TargetStatusUpdated` event.
    function setTargetPaused(address target, bool enabled) external;

    /// @notice Sets the global paused status.
    ///
    /// @param enabled Whether to enable the global pause.
    ///
    /// @dev Requirements:
    /// - Only callable by an account `_authorizeManager` accepts.
    ///
    /// Emits a `GlobalStatusUpdated` event.
    function setGloballyPaused(bool enabled) external;

    /// @notice Returns a target contract's own pause flag. Ignores the global
    /// pause; use `isPaused` for the combined status.
    ///
    /// @param target The target contract.
    ///
    /// @return result True if the target contract is paused, false otherwise.
    function isTargetPaused(address target) external view returns (bool result);

    /// @notice Returns whether the global status is paused.
    ///
    /// @return result True if the global status is paused, false otherwise.
    function isGloballyPaused() external view returns (bool result);
}
