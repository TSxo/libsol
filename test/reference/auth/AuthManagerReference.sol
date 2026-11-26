// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { IAuthManaged } from "@tsxo/libsol/auth/managed/IAuthManaged.sol";
import { IAuthManager } from "@tsxo/libsol/auth/managed/IAuthManager.sol";
import { IAuthority } from "@tsxo/libsol/auth/managed/IAuthority.sol";

/// @title AuthManagerReference
///
/// @notice A plain-Solidity reference for `AuthManager`, used to check the
/// assembly version in differential tests. Same behavior, events, and errors.
/// See `src/` for the documentation.
///
/// It stores one boolean per role instead of a bitmask, and decides access
/// with a loop and explicit rules, so it shares no bit arithmetic with the
/// assembly it is compared against. Bit operations appear only where
/// `IAuthManager` defines a bitmask as the result: `userRoles` and
/// `functionAccess` encode the booleans into the documented layout (bit r is
/// role r, bit 254 is public, bit 255 is closed).
abstract contract AuthManagerReference is IAuthManager, IAuthority {
    uint8 internal constant ROLE_COUNT = 254;
    uint8 internal constant PUBLIC_BIT = 254;
    uint8 internal constant CLOSED_BIT = 255;

    mapping(address user => mapping(uint256 role => bool)) private _hasRole;
    mapping(address target => mapping(bytes4 selector => mapping(uint256 role => bool))) private _roleAllowed;
    mapping(address target => mapping(bytes4 selector => bool)) private _isPublic;
    mapping(address target => mapping(bytes4 selector => bool)) private _isClosed;

    function setUserRole(address user, uint8 role, bool enabled) public virtual {
        _authorizeManager();
        if (role >= ROLE_COUNT) revert AuthManager__InvalidRole();

        _hasRole[user][role] = enabled;
        emit UserRoleUpdated(user, role, enabled);
    }

    function setRoleAccess(address target, bytes4 selector, uint8 role, bool enabled) public virtual {
        _authorizeManager();
        if (role >= ROLE_COUNT) revert AuthManager__InvalidRole();

        _roleAllowed[target][selector][role] = enabled;
        emit AccessUpdated(target, selector, role, enabled);
    }

    function setFunctionPublic(address target, bytes4 selector, bool enabled) public virtual {
        _authorizeManager();

        _isPublic[target][selector] = enabled;
        emit AccessUpdated(target, selector, PUBLIC_BIT, enabled);
    }

    function setFunctionClosed(address target, bytes4 selector, bool enabled) public virtual {
        _authorizeManager();

        _isClosed[target][selector] = enabled;
        emit AccessUpdated(target, selector, CLOSED_BIT, enabled);
    }

    function setAuthority(address target, address newAuthority) public virtual {
        _authorizeManager();
        if (target.code.length == 0) revert AuthManager__InvalidTarget();

        // A low-level call, so that a target that returns data is rejected:
        // `setAuthority` returns nothing.
        (bool success, bytes memory result) = target.call(abi.encodeCall(IAuthManaged.setAuthority, (newAuthority)));

        if (!success) {
            assembly ("memory-safe") {
                revert(add(result, 0x20), mload(result))
            }
        }

        if (result.length != 0) revert AuthManager__InvalidTarget();
        emit AuthorityUpdated(target, newAuthority);
    }

    /// @dev The documented rules: closed denies everyone, public admits
    /// everyone, otherwise the user needs one role the function allows.
    function canCall(address user, address target, bytes4 selector) public view virtual returns (bool) {
        if (_isClosed[target][selector]) return false;
        if (_isPublic[target][selector]) return true;

        for (uint256 role; role < ROLE_COUNT; ++role) {
            if (_hasRole[user][role] && _roleAllowed[target][selector][role]) return true;
        }

        return false;
    }

    function hasRole(address user, uint8 role) public view virtual returns (bool) {
        return role < ROLE_COUNT && _hasRole[user][role];
    }

    function roleHasAccess(address target, bytes4 selector, uint8 role) public view virtual returns (bool) {
        return role < ROLE_COUNT && _roleAllowed[target][selector][role];
    }

    function isFunctionPublic(address target, bytes4 selector) public view virtual returns (bool) {
        return _isPublic[target][selector];
    }

    function isFunctionClosed(address target, bytes4 selector) public view virtual returns (bool) {
        return _isClosed[target][selector];
    }

    function userRoles(address user) public view virtual returns (uint256 mask) {
        for (uint256 role; role < ROLE_COUNT; ++role) {
            if (_hasRole[user][role]) mask |= uint256(1) << role;
        }
    }

    function functionAccess(address target, bytes4 selector) public view virtual returns (uint256 mask) {
        for (uint256 role; role < ROLE_COUNT; ++role) {
            if (_roleAllowed[target][selector][role]) mask |= uint256(1) << role;
        }

        if (_isPublic[target][selector]) mask |= uint256(1) << PUBLIC_BIT;
        if (_isClosed[target][selector]) mask |= uint256(1) << CLOSED_BIT;
    }

    function _authorizeManager() internal view virtual;
}
