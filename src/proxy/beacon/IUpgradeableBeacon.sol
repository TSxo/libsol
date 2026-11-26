// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { IBeacon } from "./IBeacon.sol";

/// @title IUpgradeableBeacon
///
/// @author TSxo
///
/// @notice Interface for `UpgradeableBeacon`.
interface IUpgradeableBeacon is IBeacon {
    // =========================================================================
    // Events
    // =========================================================================

    /// @notice Emitted when the implementation changes.
    ///
    /// @param implementation The new implementation.
    event Upgraded(address indexed implementation);

    // =========================================================================
    // Errors
    // =========================================================================

    /// @notice The new implementation has no code.
    error UpgradeableBeacon__InvalidImplementation();

    // =========================================================================
    // Functions
    // =========================================================================

    /// @notice Points every proxy that uses this beacon at `newImplementation`.
    ///
    /// @param newImplementation The new implementation.
    function upgradeTo(address newImplementation) external;
}
