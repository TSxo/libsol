// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";

import { IOwned } from "@tsxo/libsol/auth/IOwned.sol";

import { IAuthManaged } from "@tsxo/libsol/auth/managed/IAuthManaged.sol";
import { IAuthManager } from "@tsxo/libsol/auth/managed/IAuthManager.sol";

import { AuthManagedHarness } from "test/harness/auth/AuthManagedHarness.sol";
import { AuthManagerHarness } from "test/harness/auth/AuthManagerHarness.sol";
import { RevertingTarget } from "test/mocks/AuthorityMock.sol";

interface TestEvents {
    event UserRoleUpdated(address indexed user, uint8 indexed role, bool enabled);
    event AccessUpdated(address indexed target, bytes4 indexed selector, uint8 indexed role, bool enabled);
    event AuthorityUpdated(address indexed target, address indexed newAuthority);
}

abstract contract AuthManagerTestBase is Test, TestEvents {
    // =========================================================================
    // State
    // =========================================================================

    uint8 constant MAX_ROLE = 253;
    uint8 constant PUBLIC_BIT = 254;
    uint8 constant CLOSED_BIT = 255;

    bytes4 constant INCREMENT = AuthManagedHarness.increment.selector;
    bytes4 constant DECREMENT = AuthManagedHarness.decrement.selector;

    address owner = makeAddr("owner");
    address userA = makeAddr("user-a");
    address userB = makeAddr("user-b");
    address userC = makeAddr("user-c");

    AuthManagerHarness manager;
    AuthManagedHarness managed;

    // =========================================================================
    // Set Up
    // =========================================================================

    function setUp() public {
        manager = new AuthManagerHarness(owner);
        managed = new AuthManagedHarness(address(manager));
    }
}

contract AuthManagerUserRolesTest is AuthManagerTestBase {
    function test_SetUserRole_UpdatesRoles() public {
        uint8 roleA = 0;
        uint8 roleB = 2;

        // Initial sanity check.
        assertEq(manager.userRoles(userA), 0);
        assertEq(manager.hasRole(userA, roleA), false);
        assertEq(manager.hasRole(userA, roleB), false);

        vm.startPrank(owner);

        // Grant role A.
        vm.expectEmit(true, true, false, true, address(manager));
        emit UserRoleUpdated(userA, roleA, true);

        manager.setUserRole(userA, roleA, true);

        assertEq(manager.userRoles(userA), 1);
        assertEq(manager.hasRole(userA, roleA), true);

        // Grant role B.
        vm.expectEmit(true, true, false, true, address(manager));
        emit UserRoleUpdated(userA, roleB, true);

        manager.setUserRole(userA, roleB, true);
        assertEq(manager.userRoles(userA), 5);
        assertEq(manager.hasRole(userA, roleB), true);

        // Revoke only role A.
        vm.expectEmit(true, true, false, true, address(manager));
        emit UserRoleUpdated(userA, roleA, false);

        manager.setUserRole(userA, roleA, false);
        assertEq(manager.userRoles(userA), 4);
        assertEq(manager.hasRole(userA, roleA), false);

        vm.stopPrank();
    }

    function testFuzz_SetUserRole_UpdatesRoles(address user, uint8 role, bool enabled) public {
        role = uint8(bound(role, 0, MAX_ROLE));
        assertEq(manager.userRoles(user), 0);
        assertEq(manager.hasRole(user, role), false);

        vm.expectEmit(true, true, false, true, address(manager));
        emit UserRoleUpdated(user, role, enabled);

        vm.prank(owner);
        manager.setUserRole(user, role, enabled);

        uint256 expectedBit = enabled ? 1 : 0;
        assertEq((manager.userRoles(user) >> role) & 1, expectedBit);
        assertEq(manager.hasRole(user, role), enabled);
    }

    function test_RevertWhen_SetUserRole_RoleIsInvalid() public {
        vm.startPrank(owner);

        bytes4 err = IAuthManager.AuthManager__InvalidRole.selector;
        vm.expectRevert(err);
        manager.setUserRole(userA, PUBLIC_BIT, true);

        vm.expectRevert(err);
        manager.setUserRole(userA, CLOSED_BIT, true);

        vm.stopPrank();
    }

    function testFuzz_RevertWhen_SetUserRole_CallerIsNotOwner(address user, uint8 role) public {
        vm.assume(user != owner);
        vm.prank(user);

        bytes4 err = IOwned.Owned__Unauthorized.selector;
        vm.expectRevert(err);

        manager.setUserRole(userA, role, true);
    }

    /// @dev Every valid role, 0 to 253, can be granted, and all of them together
    /// fill exactly bits 0-253.
    function test_SetUserRole_AllValidRoles() public {
        vm.startPrank(owner);
        for (uint256 role; role <= MAX_ROLE; ++role) {
            manager.setUserRole(userA, uint8(role), true);
        }
        vm.stopPrank();

        assertEq(manager.userRoles(userA), (uint256(1) << 254) - 1);
        for (uint256 role; role <= MAX_ROLE; ++role) {
            assertTrue(manager.hasRole(userA, uint8(role)));
        }
        assertFalse(manager.hasRole(userA, PUBLIC_BIT));
        assertFalse(manager.hasRole(userA, CLOSED_BIT));
    }

    function testFuzz_SetUserRole_ValidRole(address user, uint256 roleSeed, bool enabled) public {
        uint8 role = uint8(bound(roleSeed, 0, MAX_ROLE));

        vm.prank(owner);
        manager.setUserRole(user, role, enabled);

        assertEq(manager.userRoles(user), enabled ? uint256(1) << role : 0);
        assertEq(manager.hasRole(user, role), enabled);
    }
}

contract AuthManagerFunctionAccessTest is AuthManagerTestBase {
    function testFuzz_SetFunctionClosed_UpdatesFlag(address target, bytes4 selector, bool enabled) public {
        assertEq(manager.functionAccess(target, selector), 0);
        assertEq(manager.isFunctionClosed(target, selector), false);

        vm.expectEmit(true, true, false, true, address(manager));
        emit AccessUpdated(target, selector, CLOSED_BIT, enabled);

        vm.prank(owner);
        manager.setFunctionClosed(target, selector, enabled);

        uint256 expectedBit = enabled ? 1 : 0;
        assertEq((manager.functionAccess(target, selector) >> CLOSED_BIT) & 1, expectedBit);
        assertEq(manager.isFunctionClosed(target, selector), enabled);
    }

    function testFuzz_RevertWhen_SetFunctionClosed_CallerIsNotOwner(address user, address target, bytes4 selector)
        public
    {
        vm.assume(user != owner);
        vm.prank(user);

        bytes4 err = IOwned.Owned__Unauthorized.selector;
        vm.expectRevert(err);

        manager.setFunctionClosed(target, selector, true);
    }

    function testFuzz_SetFunctionPublic_UpdatesFlag(address target, bytes4 selector, bool enabled) public {
        assertEq(manager.functionAccess(target, selector), 0);
        assertEq(manager.isFunctionPublic(target, selector), false);

        vm.expectEmit(true, true, false, true, address(manager));
        emit AccessUpdated(target, selector, PUBLIC_BIT, enabled);

        vm.prank(owner);
        manager.setFunctionPublic(target, selector, enabled);

        uint256 expectedBit = enabled ? 1 : 0;
        assertEq((manager.functionAccess(target, selector) >> PUBLIC_BIT) & 1, expectedBit);
        assertEq(manager.isFunctionPublic(target, selector), enabled);
    }

    function testFuzz_RevertWhen_SetFunctionPublic_CallerIsNotOwner(address user, address target, bytes4 selector)
        public
    {
        vm.assume(user != owner);
        vm.prank(user);

        bytes4 err = IOwned.Owned__Unauthorized.selector;
        vm.expectRevert(err);

        manager.setFunctionPublic(target, selector, true);
    }

    function test_SetRoleAccess_UpdatesAccess() public {
        vm.startPrank(owner);

        address target = address(managed);
        bytes4 selector = INCREMENT;
        uint8 role = uint8(0);
        bool enabled = true;

        // Initial state check.
        assertEq(manager.functionAccess(target, selector), 0);
        assertEq(manager.roleHasAccess(target, selector, role), false);

        // Set access.
        vm.expectEmit(true, true, false, true, address(manager));
        emit AccessUpdated(target, selector, role, enabled);

        manager.setRoleAccess(target, selector, role, enabled);

        uint256 expectedBit = enabled ? 1 : 0;
        assertEq(manager.functionAccess(target, selector) & 1, expectedBit);
        assertEq(manager.roleHasAccess(target, selector, role), enabled);

        // Unset access.
        vm.expectEmit(true, true, false, true, address(manager));
        emit AccessUpdated(target, selector, role, !enabled);

        manager.setRoleAccess(target, selector, role, !enabled);

        expectedBit = !enabled ? 1 : 0;
        assertEq(manager.functionAccess(target, selector) & 1, expectedBit);
        assertEq(manager.roleHasAccess(target, selector, role), !enabled);

        vm.stopPrank();
    }

    function testFuzz_SetRoleAccess_UpdatesAccess(address target, bytes4 selector, uint8 role, bool enabled) public {
        role = uint8(bound(role, 0, MAX_ROLE));
        assertEq(manager.functionAccess(target, selector), 0);
        assertEq(manager.roleHasAccess(target, selector, role), false);

        vm.expectEmit(true, true, false, true, address(manager));
        emit AccessUpdated(target, selector, role, enabled);

        vm.prank(owner);
        manager.setRoleAccess(target, selector, role, enabled);

        uint256 expectedBit = enabled ? 1 : 0;
        assertEq((manager.functionAccess(target, selector) >> role) & 1, expectedBit);
        assertEq(manager.roleHasAccess(target, selector, role), enabled);
    }

    function test_RevertWhen_SetRoleAccess_RoleIsInvalid() public {
        vm.startPrank(owner);

        address target = address(managed);
        bytes4 selector = INCREMENT;
        bool enabled = true;

        bytes4 err = IAuthManager.AuthManager__InvalidRole.selector;
        vm.expectRevert(err);
        manager.setRoleAccess(target, selector, PUBLIC_BIT, enabled);

        vm.expectRevert(err);
        manager.setRoleAccess(target, selector, CLOSED_BIT, enabled);

        vm.stopPrank();
    }

    function testFuzz_RevertWhen_SetRoleAccess_CallerIsNotOwner(address user) public {
        vm.assume(user != owner);
        vm.prank(user);

        address target = address(managed);
        bytes4 selector = INCREMENT;
        bool enabled = true;

        bytes4 err = IOwned.Owned__Unauthorized.selector;
        vm.expectRevert(err);

        manager.setRoleAccess(target, selector, CLOSED_BIT, enabled);
    }

    /// @dev Every valid role can be granted access, and all of them together
    /// never touch the public or closed bits.
    function test_SetRoleAccess_AllValidRoles() public {
        address target = address(managed);
        bytes4 selector = INCREMENT;

        vm.startPrank(owner);
        for (uint256 role; role <= MAX_ROLE; ++role) {
            manager.setRoleAccess(target, selector, uint8(role), true);
        }
        vm.stopPrank();

        assertEq(manager.functionAccess(target, selector), (uint256(1) << 254) - 1);
        assertFalse(manager.isFunctionPublic(target, selector));
        assertFalse(manager.isFunctionClosed(target, selector));
    }
}

contract AuthManagerRoleBoundsTest is AuthManagerTestBase {
    function test_MaxRole_IsAccepted() public {
        vm.startPrank(owner);
        manager.setUserRole(userA, MAX_ROLE, true);
        manager.setRoleAccess(address(managed), INCREMENT, MAX_ROLE, true);
        vm.stopPrank();

        assertEq(manager.userRoles(userA), uint256(1) << MAX_ROLE);
        assertTrue(manager.canCall(userA, address(managed), INCREMENT));
    }

    function testFuzz_RevertWhen_Setters_RoleIsInvalid(uint256 roleSeed, bool enabled) public {
        uint8 role = uint8(bound(roleSeed, PUBLIC_BIT, CLOSED_BIT));
        bytes4 err = IAuthManager.AuthManager__InvalidRole.selector;

        vm.startPrank(owner);
        vm.expectRevert(err);
        manager.setUserRole(userA, role, enabled);

        vm.expectRevert(err);
        manager.setRoleAccess(address(managed), INCREMENT, role, enabled);
        vm.stopPrank();
    }

    /// @dev The views report bits 254 and 255 as roles nobody holds, rather than
    /// leaking the public and closed flags.
    function testFuzz_RoleViews_AreFalseAboveMaxRole(address target, bytes4 selector, uint256 roleSeed) public {
        uint8 role = uint8(bound(roleSeed, PUBLIC_BIT, CLOSED_BIT));

        vm.startPrank(owner);
        manager.setFunctionPublic(target, selector, true);
        manager.setFunctionClosed(target, selector, true);
        vm.stopPrank();

        assertFalse(manager.roleHasAccess(target, selector, role));
        assertFalse(manager.hasRole(userA, role));
    }
}

contract AuthManagerCanCallTest is AuthManagerTestBase {
    /// @dev The example used by the tests below:
    /// - userA has roles 0 and 1, userB has 1 and 2, userC has 3 and 4.
    /// - `increment` allows roles 0 and 1; `decrement` allows 1, 2, and 3.
    ///
    /// So userA and userB may call both, and userC only `decrement`.
    function _grantExampleAccess() internal {
        address target = address(managed);

        vm.startPrank(owner);
        manager.setUserRole(userA, 0, true);
        manager.setUserRole(userA, 1, true);
        manager.setUserRole(userB, 1, true);
        manager.setUserRole(userB, 2, true);
        manager.setUserRole(userC, 3, true);
        manager.setUserRole(userC, 4, true);

        manager.setRoleAccess(target, INCREMENT, 0, true);
        manager.setRoleAccess(target, INCREMENT, 1, true);
        manager.setRoleAccess(target, DECREMENT, 1, true);
        manager.setRoleAccess(target, DECREMENT, 2, true);
        manager.setRoleAccess(target, DECREMENT, 3, true);
        vm.stopPrank();
    }

    function test_CanCall_FalseWithoutAccess() public view {
        address target = address(managed);

        assertFalse(manager.canCall(userA, target, INCREMENT));
        assertFalse(manager.canCall(userB, target, INCREMENT));
        assertFalse(manager.canCall(userC, target, INCREMENT));
        assertFalse(manager.canCall(userA, target, DECREMENT));
        assertFalse(manager.canCall(userB, target, DECREMENT));
        assertFalse(manager.canCall(userC, target, DECREMENT));
    }

    function test_CanCall_TrueForSharedRole() public {
        _grantExampleAccess();
        address target = address(managed);

        assertTrue(manager.canCall(userA, target, INCREMENT));
        assertTrue(manager.canCall(userB, target, INCREMENT));
        assertTrue(manager.canCall(userA, target, DECREMENT));
        assertTrue(manager.canCall(userB, target, DECREMENT));
        assertTrue(manager.canCall(userC, target, DECREMENT));
    }

    /// @dev userC's roles, 3 and 4, are not among `increment`'s, 0 and 1.
    function test_CanCall_FalseWithoutSharedRole() public {
        _grantExampleAccess();
        assertFalse(manager.canCall(userC, address(managed), INCREMENT));
    }

    function test_CanCall_ClosedDeniesEveryone() public {
        _grantExampleAccess();
        address target = address(managed);

        vm.startPrank(owner);
        manager.setFunctionClosed(target, INCREMENT, true);
        manager.setFunctionClosed(target, DECREMENT, true);
        vm.stopPrank();

        assertFalse(manager.canCall(userA, target, INCREMENT));
        assertFalse(manager.canCall(userB, target, INCREMENT));
        assertFalse(manager.canCall(userA, target, DECREMENT));
        assertFalse(manager.canCall(userB, target, DECREMENT));
        assertFalse(manager.canCall(userC, target, DECREMENT));
    }

    function test_CanCall_PublicAdmitsEveryone() public {
        _grantExampleAccess();
        address target = address(managed);
        address nobody = makeAddr("nobody");

        vm.prank(owner);
        manager.setFunctionPublic(target, INCREMENT, true);

        assertTrue(manager.canCall(userC, target, INCREMENT), "user without a matching role");
        assertTrue(manager.canCall(nobody, target, INCREMENT), "user without any role");
        assertFalse(manager.canCall(nobody, target, DECREMENT), "other functions are unaffected");
    }

    /// @dev Closed wins over public, and public wins over roles.
    function testFuzz_CanCall_ClosedOverridesPublicOverridesRoles(uint256 roleSeed, bool hasRole) public {
        uint8 role = uint8(bound(roleSeed, 0, MAX_ROLE));
        address target = address(managed);
        bytes4 selector = INCREMENT;

        vm.startPrank(owner);
        manager.setUserRole(userA, role, hasRole);
        manager.setRoleAccess(target, selector, role, true);
        assertEq(manager.canCall(userA, target, selector), hasRole);

        manager.setFunctionPublic(target, selector, true);
        assertTrue(manager.canCall(userA, target, selector));

        manager.setFunctionClosed(target, selector, true);
        assertFalse(manager.canCall(userA, target, selector));

        manager.setFunctionPublic(target, selector, false);
        assertFalse(manager.canCall(userA, target, selector));
        vm.stopPrank();
    }
}

contract AuthManagerSetAuthorityTest is AuthManagerTestBase {
    function test_SetAuthority_UpdatesTargetAuthority() public {
        address target = address(managed);
        address newAuthority = address(new AuthManagerHarness(owner));

        vm.expectEmit(true, true, false, false, address(manager));
        emit AuthorityUpdated(target, newAuthority);

        vm.prank(owner);
        manager.setAuthority(target, newAuthority);
        assertEq(managed.authority(), newAuthority);
    }

    function testFuzz_RevertWhen_SetAuthority_CallerIsNotOwner(address user) public {
        vm.assume(user != owner);
        vm.prank(user);

        address target = address(managed);
        address newAuthority = makeAddr("new-authority");

        bytes4 err = IOwned.Owned__Unauthorized.selector;
        vm.expectRevert(err);

        manager.setAuthority(target, newAuthority);
    }

    function test_RevertWhen_SetAuthority_TargetHasNoCode() public {
        vm.prank(owner);
        vm.expectRevert(IAuthManager.AuthManager__InvalidTarget.selector);
        manager.setAuthority(makeAddr("no-code-target"), address(manager));
    }

    /// @dev The target rejects an Authority without code, and the manager passes
    /// the target's error through.
    function test_RevertWhen_SetAuthority_AuthorityHasNoCode() public {
        vm.prank(owner);
        vm.expectRevert(IAuthManaged.AuthManaged__InvalidAuthority.selector);
        manager.setAuthority(address(managed), makeAddr("no-code-authority"));
    }

    function test_RevertWhen_SetAuthority_TargetReverts() public {
        RevertingTarget target = new RevertingTarget();

        vm.prank(owner);
        vm.expectRevert(RevertingTarget.Refused.selector);
        manager.setAuthority(address(target), address(manager));
    }
}
