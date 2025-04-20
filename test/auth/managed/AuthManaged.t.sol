pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";

import { IAuthManaged } from "@tsxo/libsol/auth/managed/IAuthManaged.sol";
import { IAuthManager } from "@tsxo/libsol/auth/managed/IAuthManager.sol";

import { AuthManagedMock } from "@tsxo/libsol/mocks/auth/managed/AuthManagedMock.sol";
import { AuthManagerMock } from "@tsxo/libsol/mocks/auth/managed/AuthManagerMock.sol";

interface TestEvents {
    event AuthorityUpdated(address indexed previousAuthority, address indexed newAuthority);
}

contract AuthManagedTest is Test, TestEvents {
    // -------------------------------------------------------------------------
    // State

    uint8 constant MAX_ROLE = 253;
    uint8 constant PUBLIC_BIT = 254;
    uint8 constant CLOSED_BIT = 255;

    address constant owner = address(0x1234);
    address constant user = address(0x2345);

    AuthManagerMock manager;
    AuthManagedMock managed;

    // -------------------------------------------------------------------------
    // Set Up

    function setUp() public {
        manager = new AuthManagerMock(owner);
        managed = new AuthManagedMock(address(manager));
    }

    // -------------------------------------------------------------------------
    // Test - Set Authority

    function test_SetAuthorityRevertsOnUnauthorizedCalls() public {
        vm.prank(owner);

        bytes4 err = IAuthManaged.AuthManaged__Unauthorized.selector;
        vm.expectRevert(err);

        managed.setAuthority(owner);
    }

    function test_SetAuthority() public {
        address target = address(managed);
        address newAuthority = address(0x9876);
        vm.expectEmit(true, true, false, true, address(managed));
        emit AuthorityUpdated(address(manager), newAuthority);

        vm.prank(owner);
        manager.setAuthority(target, newAuthority);
        assertEq(managed.authority(), newAuthority);
    }

    // -------------------------------------------------------------------------
    // Test - Auth Modifier

    function test_AuthModifier() public {
        address target = address(managed);

        bytes4 err = IAuthManaged.AuthManaged__Unauthorized.selector;

        bytes4 inc = bytes4(0xd09de08a);
        bytes4 dec = bytes4(0x2baeceb7);

        // Should revert before any access is set.
        vm.startPrank(user);

        vm.expectRevert(err);
        managed.increment();

        vm.expectRevert(err);
        managed.decrement();

        vm.stopPrank();

        // Set user A's roles.
        vm.startPrank(owner);
        manager.setUserRole(user, 0, true);

        // Set `increment` function access: 0
        manager.setRoleAccess(target, inc, 0, true);

        // Set `decrement` function access: 1
        manager.setRoleAccess(target, dec, 1, true);
        vm.stopPrank();

        // Should revert if the contract is paused.
        vm.prank(owner);
        manager.setPaused(target, true);

        vm.startPrank(user);

        vm.expectRevert(err);
        managed.increment();

        vm.expectRevert(err);
        managed.decrement();

        vm.stopPrank();

        vm.prank(owner);
        manager.setPaused(target, false);

        // Should revert if the target function is closed.
        vm.startPrank(owner);
        manager.setFunctionClosed(target, inc, true);
        manager.setFunctionClosed(target, dec, true);
        vm.stopPrank();

        vm.startPrank(user);

        vm.expectRevert(err);
        managed.increment();

        vm.expectRevert(err);
        managed.decrement();

        vm.stopPrank();

        vm.startPrank(owner);
        manager.setFunctionClosed(target, inc, false);
        manager.setFunctionClosed(target, dec, false);
        vm.stopPrank();

        // Should allow the user call if the function is public, regardless of
        // roles.
        vm.startPrank(owner);
        manager.setFunctionPublic(target, inc, true);
        manager.setFunctionPublic(target, dec, true);
        vm.stopPrank();

        vm.startPrank(user);
        assertEq(managed.count(), 0);

        managed.increment();
        managed.increment();
        assertEq(managed.count(), 2);

        managed.decrement();
        managed.decrement();
        assertEq(managed.count(), 0);
        vm.stopPrank();

        vm.startPrank(owner);
        manager.setFunctionPublic(target, inc, false);
        manager.setFunctionPublic(target, dec, false);
        vm.stopPrank();

        // Should correctly determine access.
        vm.startPrank(user);
        assertEq(managed.count(), 0);

        managed.increment();
        assertEq(managed.count(), 1);

        vm.expectRevert(err);
        managed.decrement();

        vm.stopPrank();

        vm.startPrank(owner);
        manager.setUserRole(user, 0, false);
        manager.setUserRole(user, 1, true);
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(err);
        managed.increment();

        assertEq(managed.count(), 1);
        managed.decrement();
        assertEq(managed.count(), 0);
        vm.stopPrank();

        vm.prank(owner);
        manager.setUserRole(user, 1, false);

        vm.expectRevert(err);
        vm.prank(user);
        managed.increment();

        vm.expectRevert(err);
        vm.prank(user);
        managed.decrement();
    }
}
