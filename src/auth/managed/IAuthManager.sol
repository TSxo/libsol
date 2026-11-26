// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/// @title IAuthManager
///
/// @author TSxo
///
/// @notice Interface for the `AuthManager` contract.
interface IAuthManager {
    // =========================================================================
    // Events
    // =========================================================================

    /// @notice Emitted when a user's role has been updated.
    ///
    /// @param user     The user whose role was updated.
    /// @param role     The role that was updated.
    /// @param enabled  Whether the role was enabled.
    event UserRoleUpdated(address indexed user, uint8 indexed role, bool enabled);

    /// @notice Emitted when a target function's access has been updated.
    ///
    /// @param target   The target contract.
    /// @param selector The function selector that was updated.
    /// @param role     The role, or flag bit, that was updated.
    /// @param enabled  Whether the bit was set.
    ///
    /// @dev `role` is 0 to 253 for a role, 254 for the public flag, and 255 for
    /// the closed flag.
    event AccessUpdated(address indexed target, bytes4 indexed selector, uint8 indexed role, bool enabled);

    // =========================================================================
    // Errors
    // =========================================================================

    /// @notice The role is above 253.
    error AuthManager__InvalidRole();

    /// @notice The target is not a contract, or returned data from
    /// `setAuthority`.
    error AuthManager__InvalidTarget();

    // =========================================================================
    // Functions
    // =========================================================================

    /// @notice Assigns or removes a role for a user.
    ///
    /// @param user     The address of the user whose role is being modified.
    /// @param role     The role to set (0 <= role <= 253).
    /// @param enabled  True to assign the role, false to remove it.
    ///
    /// @dev Requirements:
    /// - Only callable by an account `_authorizeManager` accepts.
    /// - The role must be between 0 and 253, inclusive.
    ///
    /// Emits a `UserRoleUpdated` event.
    function setUserRole(address user, uint8 role, bool enabled) external;

    /// @notice Sets whether a function on a target contract is closed.
    ///
    /// @param target   The address of the target contract.
    /// @param selector The target function selector.
    /// @param enabled  True to close the function, false to open it.
    ///
    /// @dev Requirements:
    /// - Only callable by an account `_authorizeManager` accepts.
    ///
    /// Emits an `AccessUpdated` event.
    function setFunctionClosed(address target, bytes4 selector, bool enabled) external;

    /// @notice Sets whether a function on a target contract is public.
    ///
    /// @param target   The address of the target contract.
    /// @param selector The target function selector.
    /// @param enabled  True to make it public, false to restore role checks.
    ///
    /// @dev Requirements:
    /// - Only callable by an account `_authorizeManager` accepts.
    ///
    /// Emits an `AccessUpdated` event.
    function setFunctionPublic(address target, bytes4 selector, bool enabled) external;

    /// @notice Sets whether a specific role can access a function on a target
    /// contract.
    ///
    /// @param target   The address of the target contract.
    /// @param selector The target function selector.
    /// @param role     The role to set (0 <= role <= 253).
    /// @param enabled  True to grant access to the role, false to revoke it.
    ///
    /// @dev Requirements:
    /// - Only callable by an account `_authorizeManager` accepts.
    /// - The role must be between 0 and 253, inclusive.
    ///
    /// Emits an `AccessUpdated` event.
    function setRoleAccess(address target, bytes4 selector, uint8 role, bool enabled) external;

    /// @notice Retrieves the role bitmask for a user. Bit r is set when the
    /// user holds role r; bits 254 and 255 are always zero.
    ///
    /// @param user The address of the user.
    ///
    /// @return result The user's role bitmask.
    function userRoles(address user) external view returns (uint256 result);

    /// @notice Checks whether a user has a specific role assigned.
    ///
    /// @param user The address of the user to check.
    /// @param role The role to check (0 <= role <= 253).
    ///
    /// @return result True if the user has the role; always false above 253.
    function hasRole(address user, uint8 role) external view returns (bool result);

    /// @notice Retrieves the access bitmask for a function on a target
    /// contract: bits 0-253 are the allowed roles, bit 254 is the public flag,
    /// and bit 255 is the closed flag.
    ///
    /// @param target   The address of the target contract.
    /// @param selector The target function selector.
    ///
    /// @return result The function's access bitmask.
    function functionAccess(address target, bytes4 selector) external view returns (uint256 result);

    /// @notice Checks whether a specific role has access to a function on a
    /// target contract. Bits 254 and 255 are flags, not roles: see
    /// `isFunctionPublic` and `isFunctionClosed`.
    ///
    /// @param target   The address of the target contract.
    /// @param selector The target function selector.
    /// @param role     The role to check (0 <= role <= 253).
    ///
    /// @return result True if the role is allowed; always false above 253.
    function roleHasAccess(address target, bytes4 selector, uint8 role) external view returns (bool result);

    /// @notice Checks whether a function on a target contract is closed.
    ///
    /// @param target   The address of the target contract.
    /// @param selector The target function selector.
    ///
    /// @return result True if the function is closed, false otherwise.
    function isFunctionClosed(address target, bytes4 selector) external view returns (bool result);

    /// @notice Checks whether a function on a target contract is public.
    ///
    /// @param target   The address of the target contract.
    /// @param selector The target function selector.
    ///
    /// @return result True if the function is public, false otherwise.
    function isFunctionPublic(address target, bytes4 selector) external view returns (bool result);
}
