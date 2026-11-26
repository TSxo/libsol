// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";

import { IAuthManaged } from "@tsxo/libsol/auth/managed/IAuthManaged.sol";
import { IAuthManager } from "@tsxo/libsol/auth/managed/IAuthManager.sol";

import { AuthManagedHarness } from "test/harness/auth/AuthManagedHarness.sol";
import { AuthManagerHarness } from "test/harness/auth/AuthManagerHarness.sol";
import { AuthorityMock } from "test/mocks/AuthorityMock.sol";

interface TestEvents {
    event AuthorityUpdated(address indexed previousAuthority, address indexed newAuthority);
}

abstract contract AuthManagedTestBase is Test, TestEvents {
    // =========================================================================
    // State
    // =========================================================================

    uint8 constant MAX_ROLE = 253;
    uint8 constant PUBLIC_BIT = 254;
    uint8 constant CLOSED_BIT = 255;

    bytes4 constant INCREMENT = AuthManagedHarness.increment.selector;
    bytes4 constant DECREMENT = AuthManagedHarness.decrement.selector;

    address owner = makeAddr("owner");
    address user = makeAddr("user");

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

contract AuthManagedSetAuthorityTest is AuthManagedTestBase {
    function test_Constructor_SetsAuthority() public view {
        assertEq(managed.authority(), address(manager));
    }

    function test_RevertWhen_Constructor_AuthorityHasNoCode() public {
        vm.expectRevert(IAuthManaged.AuthManaged__InvalidAuthority.selector);
        new AuthManagedHarness(makeAddr("no-code-authority"));
    }

    function test_SetAuthority_UpdatesAuthority() public {
        address target = address(managed);
        address newAuthority = address(new AuthManagerHarness(owner));

        vm.expectEmit(true, true, false, false, address(managed));
        emit AuthorityUpdated(address(manager), newAuthority);

        vm.prank(owner);
        manager.setAuthority(target, newAuthority);
        assertEq(managed.authority(), newAuthority);
    }

    function test_RevertWhen_SetAuthority_CallerIsNotAuthority() public {
        vm.prank(owner);

        bytes4 err = IAuthManaged.AuthManaged__Unauthorized.selector;
        vm.expectRevert(err);

        managed.setAuthority(owner);
    }
}

contract AuthManagedAuthTest is AuthManagedTestBase {
    /// @dev The example used by the tests below: `increment` allows role 0
    /// and `decrement` allows role 1, and `user` has role 0. So `user` may call
    /// `increment` but not `decrement`.
    function _grantExampleAccess() internal {
        address target = address(managed);

        vm.startPrank(owner);
        manager.setRoleAccess(target, INCREMENT, 0, true);
        manager.setRoleAccess(target, DECREMENT, 1, true);
        manager.setUserRole(user, 0, true);
        vm.stopPrank();
    }

    function test_RevertWhen_Auth_NoAccessIsSet() public {
        vm.startPrank(user);

        vm.expectRevert(IAuthManaged.AuthManaged__Unauthorized.selector);
        managed.increment();

        vm.expectRevert(IAuthManaged.AuthManaged__Unauthorized.selector);
        managed.decrement();

        vm.stopPrank();
    }

    function test_Auth_AllowsCallerWithRole() public {
        _grantExampleAccess();

        vm.prank(user);
        managed.increment();

        assertEq(managed.count(), 1);
    }

    function test_RevertWhen_Auth_CallerLacksRole() public {
        _grantExampleAccess();

        vm.expectRevert(IAuthManaged.AuthManaged__Unauthorized.selector);
        vm.prank(user);
        managed.decrement();
    }

    function test_RevertWhen_Auth_FunctionIsClosed() public {
        _grantExampleAccess();

        vm.prank(owner);
        manager.setFunctionClosed(address(managed), INCREMENT, true);

        vm.expectRevert(IAuthManaged.AuthManaged__Unauthorized.selector);
        vm.prank(user);
        managed.increment();
    }

    function test_Auth_PublicFunctionAllowsAnyone() public {
        vm.prank(owner);
        manager.setFunctionPublic(address(managed), INCREMENT, true);

        vm.prank(makeAddr("nobody"));
        managed.increment();

        assertEq(managed.count(), 1);
    }

    /// @dev End to end: access follows the user's roles as the Authority's
    /// owner changes them, with no change to the target.
    function test_Auth_FollowsRoleChanges() public {
        _grantExampleAccess();

        // Role 0: `increment` only.
        vm.prank(user);
        managed.increment();

        // Move the user to role 1: now `decrement` only.
        vm.startPrank(owner);
        manager.setUserRole(user, 0, false);
        manager.setUserRole(user, 1, true);
        vm.stopPrank();

        vm.expectRevert(IAuthManaged.AuthManaged__Unauthorized.selector);
        vm.prank(user);
        managed.increment();

        vm.prank(user);
        managed.decrement();
        assertEq(managed.count(), 0);

        // Revoke the last role: nothing.
        vm.prank(owner);
        manager.setUserRole(user, 1, false);

        vm.expectRevert(IAuthManaged.AuthManaged__Unauthorized.selector);
        vm.prank(user);
        managed.decrement();
    }

    function test_RevertWhen_Auth_AuthorityReverts() public {
        AuthorityMock authority = new AuthorityMock();
        AuthManagedHarness target = new AuthManagedHarness(address(authority));
        authority.configure(AuthorityMock.Mode.Revert, 0);

        vm.expectRevert(AuthorityMock.Rejected.selector);
        target.increment();
    }

    function test_RevertWhen_Auth_ReplyIsMalformed() public {
        AuthorityMock authority = new AuthorityMock();
        AuthManagedHarness target = new AuthManagedHarness(address(authority));
        authority.configure(AuthorityMock.Mode.ReturnShort, 1);

        vm.expectRevert(IAuthManaged.AuthManaged__InvalidAuthority.selector);
        target.increment();
    }

    /// @dev Only an ABI-encoded `true` (exactly 1) grants access; any other word
    /// fails closed.
    function testFuzz_Auth_OnlyExactTrueGrantsAccess(uint256 word) public {
        AuthorityMock authority = new AuthorityMock();
        AuthManagedHarness target = new AuthManagedHarness(address(authority));
        authority.configure(AuthorityMock.Mode.ReturnWord, word);

        if (word != 1) vm.expectRevert(IAuthManaged.AuthManaged__Unauthorized.selector);
        target.increment();
    }
}
