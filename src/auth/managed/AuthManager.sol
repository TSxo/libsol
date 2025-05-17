// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IAuthManaged } from "./IAuthManaged.sol";
import { IAuthManager } from "./IAuthManager.sol";
import { IAuthority } from "./IAuthority.sol";

/// @title AuthManager
///
/// @author TSxo
///
/// @dev This contract provides an efficient and flexible solution for managing
/// the permissions of a system.
///
/// # Target Contracts
///
/// A smart contract under the control of an `AuthManager` instance is known as a
/// target. Target contracts will inherit from the `AuthManaged` contract and
/// implement the `auth` modifier on all functions that should be subject to
/// access control. Any functions that do not implement this modifier will not
/// be managed.
///
/// # User Roles
///
/// Roles are identified by `uint8` values ranging between 0 to 253, allowing
/// for 254 distinct roles.
///
/// Each user's active roles are stored in a 256-bit bitmask, where each bit
/// from 0 to 253 corresponds to a role (1 if assigned, 0 if not). Bits 254 and
/// 255 are unused in the user roles bitmask.
///
/// # Access Control
///
/// Access rules are scoped by target and function selector. These rules are
/// stored in a 256-bitmask, where:
/// - Bits 0-253: Represent the roles permitted to call the function.
/// - Bit 254: Indicates whether the function is "public" and callable by anyone.
/// - Bit 255: Indicates whether the function is "closed" and inaccessible to all.
///
/// If a target function is neither public nor closed, access is restricted to
/// users with at least one role matching the allowed roles (bits 0 to 253) in
/// the function’s bitmask.
///
/// # Owner
///
/// All the permissions managed by this system can be modified by the owner of
/// this instance. It is expected that this account will be highly secured.
///
/// To determine the owner, this contract performs a staticcall to its own
/// `owner()` function. This allows compatibility with any contract that adheres
/// to the ERC-173 ownership standard.
///
/// # Upgrade Compatible
///
/// This contract utilizes ERC-7201 namespaced storage, making it compatible with
/// upgradeable contract architectures.
///
/// # Acknowledgements
///
/// Heavy inspiration is taken from:
/// - OpenZeppelin;
/// - Solmate; and
/// - Solady.
///
/// Thank you.
abstract contract AuthManager is IAuthManager, IAuthority {
    // -------------------------------------------------------------------------
    // Type Declarations

    /// @custom:storage-location erc7201:libsol.storage.AuthManager
    struct AuthManagerStorage {
        mapping(address => uint256) userRoles;
        mapping(address => mapping(bytes4 => uint256)) access;
    }

    // -------------------------------------------------------------------------
    // State

    /// @dev keccak256(abi.encode(uint256(keccak256("libsol.storage.AuthManager")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant AUTH_MANAGER_SLOT = 0x938700b07e50a0d76711cd0ee77205e6b6a2709fd62fa43819e05a1a4baac400;

    /// @dev keccak256(bytes("UserRoleUpdated(address,uint8,bool)"))
    bytes32 private constant USER_ROLE_UPDATED = 0x4c9bdd0c8e073eb5eda2250b18d8e5121ff27b62064fbeeeed4869bb99bc5bf2;

    /// @dev keccak256(bytes("AccessUpdated(address,bytes4,uint8,bool)"))
    bytes32 private constant ACCESS_UPDATED = 0xdb20781f7ac6b1c66139899bc76388269b478dbb402af50576a4c997b473d564;

    /// @dev keccak256(bytes("AuthorityUpdated(address,address)"))
    bytes32 private constant AUTHORITY_UPDATED = 0xa3396fd7f6e0a21b50e5089d2da70d5ac0a3bbbd1f617a93f134b76389980198;

    /// @dev uint256(1) << 255
    bytes32 private constant CLOSED_MASK = 0x8000000000000000000000000000000000000000000000000000000000000000;

    /// @dev uint256(1) << 254
    bytes32 private constant PUBLIC_MASK = 0x4000000000000000000000000000000000000000000000000000000000000000;

    /// @dev (uint256(1) << 254) - 1
    bytes32 private constant ROLES_MASK = 0x3fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    /// @dev Bit position indicating whether a function is closed.
    uint8 private constant CLOSED_SHIFT = 255;

    /// @dev Bit position indicating whether a function is public.
    uint8 private constant PUBLIC_SHIFT = 254;

    /// @dev Maximum role index allowed.
    uint8 private constant MAX_ROLE = 253;

    // -------------------------------------------------------------------------
    // Functions - Public

    /// @inheritdoc IAuthManager
    function setUserRole(address user, uint8 role, bool enabled) public virtual {
        _assertAuthManagerOwner();
        _assertValidRole(role);
        _setUserRole(user, role, enabled);
    }

    /// @inheritdoc IAuthManager
    function setFunctionClosed(address target, bytes4 selector, bool enabled) public virtual {
        _assertAuthManagerOwner();
        _setAccess(target, selector, CLOSED_SHIFT, enabled);
    }

    /// @inheritdoc IAuthManager
    function setFunctionPublic(address target, bytes4 selector, bool enabled) public virtual {
        _assertAuthManagerOwner();
        _setAccess(target, selector, PUBLIC_SHIFT, enabled);
    }

    /// @inheritdoc IAuthManager
    function setRoleAccess(address target, bytes4 selector, uint8 role, bool enabled) public virtual {
        _assertAuthManagerOwner();
        _assertValidRole(role);
        _setAccess(target, selector, role, enabled);
    }

    /// @inheritdoc IAuthority
    function setAuthority(address target, address newAuthority) public virtual {
        _assertAuthManagerOwner();

        assembly ("memory-safe") {
            mstore(0x00, shl(224, 0x7a9e5e4b)) // `setAuthority(address)`
            mstore(0x04, newAuthority)

            let success := call(gas(), target, 0x00, 0x00, 0x24, 0x00, 0x00)

            if iszero(success) { revert(0x00, 0x00) }
            if iszero(eq(returndatasize(), 0x00)) { revert(0x00, 0x00) }

            log3(0x00, 0x00, AUTHORITY_UPDATED, target, newAuthority)
        }
    }

    /// @inheritdoc IAuthority
    function canCall(address user, address target, bytes4 selector) public view virtual returns (bool result) {
        assembly ("memory-safe") {
            // Retrieve the target function's access rules.
            mstore(0x00, target)
            mstore(0x20, add(AUTH_MANAGER_SLOT, 1))
            let innerSlot := keccak256(0x00, 0x40)

            mstore(0x00, selector)
            mstore(0x20, innerSlot)
            let slot := keccak256(0x00, 0x40)

            let accessMask := sload(slot)

            // Check whether the target function is closed.
            if and(accessMask, CLOSED_MASK) {
                mstore(0x00, 0x00)
                return(0x00, 0x20)
            }

            // Check whether the target function is public.
            if and(accessMask, PUBLIC_MASK) {
                mstore(0x00, 0x01)
                return(0x00, 0x20)
            }

            // Create the valid roles mask.
            let rolesMask := and(accessMask, ROLES_MASK)

            // Retrieve the user's active roles.
            mstore(0x00, user)
            mstore(0x20, AUTH_MANAGER_SLOT)
            slot := keccak256(0x00, 0x40)

            let roles := sload(slot)

            // Check whether the user is allowed to call.
            result := iszero(iszero(and(roles, rolesMask)))
        }
    }

    /// @inheritdoc IAuthManager
    function userRoles(address user) public view virtual returns (uint256 result) {
        assembly ("memory-safe") {
            mstore(0x00, user)
            mstore(0x20, AUTH_MANAGER_SLOT)
            let slot := keccak256(0x00, 0x40)

            result := sload(slot)
        }
    }

    /// @inheritdoc IAuthManager
    function hasRole(address user, uint8 role) public view virtual returns (bool result) {
        assembly ("memory-safe") {
            mstore(0x00, user)
            mstore(0x20, AUTH_MANAGER_SLOT)
            let slot := keccak256(0x00, 0x40)

            result := iszero(iszero(and(sload(slot), shl(role, 1))))
        }
    }

    /// @inheritdoc IAuthManager
    function functionAccess(address target, bytes4 selector) public view virtual returns (uint256 result) {
        assembly ("memory-safe") {
            mstore(0x00, target)
            mstore(0x20, add(AUTH_MANAGER_SLOT, 1))
            let innerSlot := keccak256(0x00, 0x40)

            mstore(0x00, selector)
            mstore(0x20, innerSlot)
            result := sload(keccak256(0x00, 0x40))
        }
    }

    /// @inheritdoc IAuthManager
    function roleHasAccess(address target, bytes4 selector, uint8 role) public view virtual returns (bool result) {
        assembly ("memory-safe") {
            mstore(0x00, target)
            mstore(0x20, add(AUTH_MANAGER_SLOT, 1))
            let innerSlot := keccak256(0x00, 0x40)

            mstore(0x00, selector)
            mstore(0x20, innerSlot)
            let slot := keccak256(0x00, 0x40)

            let data := sload(slot)
            result := iszero(iszero(and(data, shl(role, 1))))
        }
    }

    /// @inheritdoc IAuthManager
    function isFunctionClosed(address target, bytes4 selector) public view virtual returns (bool result) {
        assembly ("memory-safe") {
            mstore(0x00, target)
            mstore(0x20, add(AUTH_MANAGER_SLOT, 1))
            let innerSlot := keccak256(0x00, 0x40)

            mstore(0x00, selector)
            mstore(0x20, innerSlot)
            let slot := keccak256(0x00, 0x40)

            let data := sload(slot)
            result := iszero(iszero(and(data, CLOSED_MASK)))
        }
    }

    /// @inheritdoc IAuthManager
    function isFunctionPublic(address target, bytes4 selector) public view virtual returns (bool result) {
        assembly ("memory-safe") {
            mstore(0x00, target)
            mstore(0x20, add(AUTH_MANAGER_SLOT, 1))
            let innerSlot := keccak256(0x00, 0x40)

            mstore(0x00, selector)
            mstore(0x20, innerSlot)
            let slot := keccak256(0x00, 0x40)

            let data := sload(slot)
            result := iszero(iszero(and(data, PUBLIC_MASK)))
        }
    }

    // -------------------------------------------------------------------------
    // Functions - Internal

    /// @notice Sets or clears a specific bit in a user’s role bitmask.
    ///
    /// @param user     The address of the user.
    /// @param role     The bit to set.
    /// @param enabled  True to set the bit, false to zero it out.
    ///
    /// @dev Internal function with no access control or restriction regarding
    /// the bit that can be set.
    ///
    /// Emits a `UserRoleUpdated` event.
    function _setUserRole(address user, uint8 role, bool enabled) internal virtual {
        assembly ("memory-safe") {
            mstore(0x00, user)
            mstore(0x20, AUTH_MANAGER_SLOT)
            let slot := keccak256(0x00, 0x40)

            switch enabled
            case 0 { sstore(slot, and(sload(slot), not(shl(role, 1)))) }
            case 1 { sstore(slot, or(sload(slot), shl(role, 1))) }

            mstore(0x00, enabled)
            log3(0x00, 0x20, USER_ROLE_UPDATED, user, role)
        }
    }

    /// @notice Sets or clears a specific bit in a function’s access bitmask.
    ///
    /// @param target   The address of the target contract.
    /// @param selector The target function selector.
    /// @param shift    The bit to set.
    /// @param enabled  True to set the bit, false to zero it out.
    ///
    /// @dev Internal function with no access control or restriction regarding
    /// the bit that can be set.
    ///
    /// Emits an `AccessUpdated` event.
    function _setAccess(address target, bytes4 selector, uint8 shift, bool enabled) internal virtual {
        assembly ("memory-safe") {
            mstore(0x00, target)
            mstore(0x20, add(AUTH_MANAGER_SLOT, 1))
            let innerSlot := keccak256(0x00, 0x40)

            mstore(0x00, selector)
            mstore(0x20, innerSlot)
            let slot := keccak256(0x00, 0x40)

            switch enabled
            case 0 { sstore(slot, and(sload(slot), not(shl(shift, 1)))) }
            case 1 { sstore(slot, or(sload(slot), shl(shift, 1))) }

            mstore(0x00, enabled)
            log4(0x00, 0x20, ACCESS_UPDATED, target, selector, shift)
        }
    }

    /// @notice Asserts that the caller is the owner of the contract.
    function _assertAuthManagerOwner() internal virtual {
        assembly ("memory-safe") {
            mstore(0x00, 0x8da5cb5b) // `owner()`
            let success := staticcall(gas(), address(), 0x1c, 0x04, 0x00, 0x20)

            if iszero(success) { revert(0x00, 0x00) }
            if iszero(eq(returndatasize(), 0x20)) { revert(0x00, 0x00) }

            if iszero(eq(caller(), mload(0x00))) {
                mstore(0x0, 0x336eb95b) // `AuthManager__Unauthorized()`
                revert(0x1c, 0x04)
            }
        }
    }

    /// @notice Asserts that a role is valid and within bounds.
    ///
    /// @param role The role to validate.
    function _assertValidRole(uint8 role) internal virtual {
        assembly ("memory-safe") {
            if gt(role, MAX_ROLE) {
                mstore(0x00, 0x0d8b3f32) // `AuthManager__InvalidRole()`
                revert(0x1c, 0x04)
            }
        }
    }
}
