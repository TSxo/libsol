// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/// @title IAuthManager
///
/// @author TSxo
///
/// @notice The interface for the AuthManager contract.
interface IAuthManager {
    // -------------------------------------------------------------------------
    // Events

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
    /// @param role     The role that was updated.
    /// @param enabled  Whether the role was enabled.
    event AccessUpdated(address indexed target, bytes4 indexed selector, uint8 indexed role, bool enabled);

    // -------------------------------------------------------------------------
    // Errors

    /// @notice Raised when a caller does not have permission to invoke a target
    /// function.
    error AuthManager__Unauthorized();

    /// @notice Raised when attempting to set an invalid role.
    error AuthManager__InvalidRole();

    // -------------------------------------------------------------------------
    // Functions

    /// @notice Assigns or removes a role for a user.
    ///
    /// @param user     The address of the user whose role is being modified.
    /// @param role     The role to set (0 <= role <= 253).
    /// @param enabled  True to assign the role, false to remove it.
    ///
    /// @dev Requirements:
    /// - Only callable by the owner.
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
    /// - Only callable by the owner.
    ///
    /// Emits an `AccessUpdated` event.
    function setFunctionClosed(address target, bytes4 selector, bool enabled) external;

    /// @notice Sets whether a function on a target contract is public.
    ///
    /// @param target   The address of the target contract.
    /// @param selector The target function selector.
    /// @param enabled  True to make the function public, false to place it under access control.
    ///
    /// @dev Requirements:
    /// - Only callable by the owner.
    ///
    /// Emits an `AccessUpdated` event.
    function setFunctionPublic(address target, bytes4 selector, bool enabled) external;

    /// @notice Sets whether a specific role can access a function on a target contract.
    ///
    /// @param target   The address of the target contract.
    /// @param selector The target function selector.
    /// @param role     The role to set (0 <= role <= 253).
    /// @param enabled  True to grant access to the role, false to revoke it.
    ///
    /// @dev Requirements:
    /// - Only callable by the owner.
    /// - The role must be between 0 and 253, inclusive.
    ///
    /// Emits an `AccessUpdated` event.
    function setRoleAccess(address target, bytes4 selector, uint8 role, bool enabled) external;

    /// @notice Retrieves the role bitmask for a user.
    ///
    /// @param user The address of the user.
    ///
    /// @return result The 256-bit role bitmask. Bits 0-253 indicate assigned
    /// roles. Bits 254 and 255 are unused.
    function userRoles(address user) external view returns (uint256 result);

    /// @notice Checks whether a user has a specific role assigned.
    ///
    /// @param user The address of the user to check.
    /// @param role The role to check (0 <= role <= 253).
    ///
    /// @return result True if the user has the specified role, false otherwise.
    function hasRole(address user, uint8 role) external view returns (bool result);

    /// @notice Retrieves the access bitmask for a function on a target contract.
    ///
    /// @param target   The address of the target contract.
    /// @param selector The target function selector.
    ///
    /// @return result The 256-bit access bitmask, where:
    /// - Bits 0-253 indicate allowed roles.
    /// - Bit 254 indicates if the function is public.
    /// - Bit 255 indicates if the function is closed.
    function functionAccess(address target, bytes4 selector) external view returns (uint256 result);

    /// @notice Checks whether a specific role has access to a function on a
    /// target contract.
    ///
    /// @param target   The address of the target contract.
    /// @param selector The target function selector.
    /// @param role     The role to check (0 <= role <= 253).
    ///
    /// @return result True if the role is allowed to call the function, false otherwise.
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
