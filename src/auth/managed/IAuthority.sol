// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/// @title IAuthority
///
/// @author TSxo
///
/// @notice Interface that every Authority must implement.
interface IAuthority {
    // =========================================================================
    // Events
    // =========================================================================

    /// @notice Emitted when a target contract's Authority is updated.
    ///
    /// @param target       The target contract.
    /// @param newAuthority The address of the new Authority.
    ///
    /// @dev Shares its signature with `IAuthManaged.AuthorityUpdated`, which
    /// the target emits with (previous, new) Authority. Indexers should tell
    /// the two apart by the emitting contract.
    event AuthorityUpdated(address indexed target, address indexed newAuthority);

    // =========================================================================
    // Functions
    // =========================================================================

    /// @notice Checks whether a caller is allowed to invoke a specific function
    /// on a target contract.
    ///
    /// @param caller   The address calling the function.
    /// @param target   The target contract.
    /// @param selector The target function selector.
    ///
    /// @return result True if the caller may call the function.
    function canCall(address caller, address target, bytes4 selector) external view returns (bool result);

    /// @notice Updates the Authority of the target contract.
    ///
    /// @param target       The target contract.
    /// @param newAuthority The address of the new Authority.
    ///
    /// @dev Requirements:
    /// - `target` must be a contract.
    /// - `newAuthority` must be a contract; the target enforces this.
    function setAuthority(address target, address newAuthority) external;
}
