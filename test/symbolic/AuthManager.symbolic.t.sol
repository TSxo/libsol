// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";

import { AuthManager } from "@tsxo/libsol/auth/managed/AuthManager.sol";
import { Owned } from "@tsxo/libsol/auth/Owned.sol";

import { CounterTarget } from "test/mocks/CounterTarget.sol";

/// @dev `AuthManager` managed by an owner, without the brutalization in
/// `test/harness/`: it draws randomness from `gasleft()`, which symbolic
/// execution does not model, and symbolic inputs are already arbitrary.
contract SymbolicAuthManager is Owned, AuthManager {
    constructor(address initialOwner) {
        _initializeOwned(initialOwner);
    }

    function _authorizeManager() internal view override onlyOwner { }
}

/// @notice Symbolic proofs for `AuthManager`'s bitmask logic.
///
/// Each check writes symbolic 256-bit words straight into the manager's
/// storage with `vm.store`, so the solver proves the property for every
/// possible bitmask rather than for sampled ones. Run with `just symbolic`.
contract AuthManagerSymbolicTest is Test {
    address owner = makeAddr("owner");
    address user = makeAddr("user");
    address target = makeAddr("target");
    bytes4 constant selector = CounterTarget.increment.selector;

    uint8 constant MAX_ROLE = 253;
    uint256 constant ROLES_MASK = (uint256(1) << 254) - 1;

    SymbolicAuthManager manager;

    function setUp() public {
        manager = new SymbolicAuthManager(owner);
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    function _base() internal pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256("libsol.storage.AuthManager")) - 1)) & ~bytes32(uint256(0xff));
    }

    function _rolesSlot(address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(account, _base()));
    }

    function _accessSlot(address target_, bytes4 selector_) internal pure returns (bytes32) {
        return keccak256(abi.encode(selector_, keccak256(abi.encode(target_, uint256(_base()) + 1))));
    }

    function _store(uint256 roles, uint256 access) internal {
        vm.store(address(manager), _rolesSlot(user), bytes32(roles));
        vm.store(address(manager), _accessSlot(target, selector), bytes32(access));
    }

    // =========================================================================
    // Checks - Access Rule
    // =========================================================================

    /// @dev For every user and access bitmask, `canCall` follows the documented
    /// rule: closed denies, public admits, otherwise any shared role in 0-253.
    function check_CanCall_MatchesRule(uint256 roles, uint256 access) public {
        _store(roles, access);

        bool closed = (access >> 255) & 1 == 1;
        bool isPublic = (access >> 254) & 1 == 1;
        bool expected = closed ? false : (isPublic || (roles & access & ROLES_MASK) != 0);

        assertEq(manager.canCall(user, target, selector), expected);
    }

    // =========================================================================
    // Checks - Views
    // =========================================================================

    /// @dev `hasRole` and `roleHasAccess` report exactly the stored bit for
    /// roles 0 to 253.
    function check_RoleViews_ReportStoredBit(uint256 roles, uint256 access, uint8 role) public {
        vm.assume(role <= MAX_ROLE);
        _store(roles, access);

        assertEq(manager.hasRole(user, role), (roles >> role) & 1 == 1);
        assertEq(manager.roleHasAccess(target, selector, role), (access >> role) & 1 == 1);
    }

    /// @dev Roles 254 and 255 are never reported, whatever is stored.
    function check_RoleViews_IgnoreFlagBits(uint256 roles, uint256 access, uint8 role) public {
        vm.assume(role > MAX_ROLE);
        _store(roles, access);

        assertFalse(manager.hasRole(user, role));
        assertFalse(manager.roleHasAccess(target, selector, role));
    }

    // =========================================================================
    // Checks - Setters
    // =========================================================================

    /// @dev `setUserRole` changes exactly bit `role` of the user's bitmask.
    function check_SetUserRole_ChangesOneBit(uint256 prior, uint8 role, bool enabled) public {
        vm.assume(role <= MAX_ROLE);
        vm.store(address(manager), _rolesSlot(user), bytes32(prior));

        vm.prank(owner);
        manager.setUserRole(user, role, enabled);

        uint256 after_ = manager.userRoles(user);
        uint256 bit = uint256(1) << role;

        assertEq(after_ & ~bit, prior & ~bit);
        assertEq(after_ & bit != 0, enabled);
    }

    /// @dev `setRoleAccess`, `setFunctionPublic`, and `setFunctionClosed` each
    /// change exactly one bit of the function's access bitmask.
    function check_AccessSetters_ChangeOneBit(uint256 prior, uint8 role, uint8 which, bool enabled) public {
        vm.assume(role <= MAX_ROLE);
        vm.store(address(manager), _accessSlot(target, selector), bytes32(prior));

        uint256 position;
        vm.startPrank(owner);
        if (which % 3 == 0) {
            manager.setRoleAccess(target, selector, role, enabled);
            position = role;
        } else if (which % 3 == 1) {
            manager.setFunctionPublic(target, selector, enabled);
            position = 254;
        } else {
            manager.setFunctionClosed(target, selector, enabled);
            position = 255;
        }
        vm.stopPrank();

        uint256 after_ = manager.functionAccess(target, selector);
        uint256 bit = uint256(1) << position;

        assertEq(after_ & ~bit, prior & ~bit);
        assertEq(after_ & bit != 0, enabled);
    }
}
