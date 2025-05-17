pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";

import { IAuthManaged } from "@tsxo/libsol/auth/managed/IAuthManaged.sol";
import { IAuthManager } from "@tsxo/libsol/auth/managed/IAuthManager.sol";

import { AuthManagedMock } from "@tsxo/libsol/mocks/auth/managed/AuthManagedMock.sol";
import { AuthManagerMock } from "@tsxo/libsol/mocks/auth/managed/AuthManagerMock.sol";

interface TestEvents {
    event UserRoleUpdated(address indexed user, uint8 indexed role, bool enabled);
    event AccessUpdated(address indexed target, bytes4 indexed selector, uint8 indexed role, bool enabled);
    event AuthorityUpdated(address indexed target, address indexed newAuthority);
}

contract AuthManagerTest is Test, TestEvents {
    // -------------------------------------------------------------------------
    // State

    uint8 constant MAX_ROLE = 253;
    uint8 constant PUBLIC_BIT = 254;
    uint8 constant CLOSED_BIT = 255;

    address constant owner = address(0x1234);
    address constant userA = address(0x2345);
    address constant userB = address(0x3456);
    address constant userC = address(0x4567);

    AuthManagerMock manager;
    AuthManagedMock managed;

    // -------------------------------------------------------------------------
    // Set Up

    function setUp() public {
        manager = new AuthManagerMock(owner);
        managed = new AuthManagedMock(address(manager));
    }

    // -------------------------------------------------------------------------
    // Test - Set User Roles

    function test_SetUserRoles() public {
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

    function testFuzz_SetUserRoles(address user, uint8 role, bool enabled) public {
        vm.assume(role <= 253);
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

    function test_SetUserRoleRevertsWithInvalidRole() public {
        vm.startPrank(owner);

        bytes4 err = IAuthManager.AuthManager__InvalidRole.selector;
        vm.expectRevert(err);
        manager.setUserRole(userA, PUBLIC_BIT, true);

        vm.expectRevert(err);
        manager.setUserRole(userA, CLOSED_BIT, true);

        vm.stopPrank();
    }

    function testFuzz_OnlyOwnerCanSetUserRole(address user, uint8 role) public {
        vm.assume(user != owner);
        vm.prank(user);

        bytes4 err = IAuthManager.AuthManager__Unauthorized.selector;
        vm.expectRevert(err);

        manager.setUserRole(userA, role, true);
    }

    // -------------------------------------------------------------------------
    // Test - Set Function Closed

    function testFuzz_SetFunctionClosed(address target, bytes4 selector, bool enabled) public {
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

    function testFuzz_OnlyOwnerCanSetFunctionClosed(address user, address target, bytes4 selector) public {
        vm.assume(user != owner);
        vm.prank(user);

        bytes4 err = IAuthManager.AuthManager__Unauthorized.selector;
        vm.expectRevert(err);

        manager.setFunctionClosed(target, selector, true);
    }

    // -------------------------------------------------------------------------
    // Test - Set Function Public

    function testFuzz_SetFunctionPublic(address target, bytes4 selector, bool enabled) public {
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

    function testFuzz_OnlyOwnerCanSetFunctionPublic(address user, address target, bytes4 selector) public {
        vm.assume(user != owner);
        vm.prank(user);

        bytes4 err = IAuthManager.AuthManager__Unauthorized.selector;
        vm.expectRevert(err);

        manager.setFunctionPublic(target, selector, true);
    }

    // -------------------------------------------------------------------------
    // Test - Set Role Access

    function test_SetRoleAccess() public {
        vm.startPrank(owner);

        address target = address(managed);
        bytes4 selector = bytes4(0xd09de08a); // `increment()`
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

    function testFuzz_SetRoleAccess(address target, bytes4 selector, uint8 role, bool enabled) public {
        vm.assume(role <= 253);
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

    function test_SetRoleAccessRevertsWithInvalidRole() public {
        vm.startPrank(owner);

        address target = address(managed);
        bytes4 selector = bytes4(0xd09de08a); // `increment()`
        bool enabled = true;

        bytes4 err = IAuthManager.AuthManager__InvalidRole.selector;
        vm.expectRevert(err);
        manager.setRoleAccess(target, selector, PUBLIC_BIT, enabled);

        vm.expectRevert(err);
        manager.setRoleAccess(target, selector, CLOSED_BIT, enabled);

        vm.stopPrank();
    }

    function testFuzz_OnlyOwnerCanSetRoleAccess(address user) public {
        vm.assume(user != owner);
        vm.prank(user);

        address target = address(managed);
        bytes4 selector = bytes4(0xd09de08a); // `increment()`
        bool enabled = true;

        bytes4 err = IAuthManager.AuthManager__Unauthorized.selector;
        vm.expectRevert(err);

        manager.setRoleAccess(target, selector, CLOSED_BIT, enabled);
    }

    // -------------------------------------------------------------------------
    // Test - Set Authority

    function test_SetAuthority() public {
        address target = address(managed);
        address newAuthority = address(0x9876);

        vm.expectEmit(true, true, false, false, address(manager));
        emit AuthorityUpdated(target, newAuthority);

        vm.prank(owner);
        manager.setAuthority(target, newAuthority);
        assertEq(managed.authority(), newAuthority);
    }

    function testFuzz_OnlyOwnerCanSetAuthority(address user) public {
        vm.assume(user != owner);
        vm.prank(user);

        address target = address(managed);
        address newAuthority = address(0x9876);

        bytes4 err = IAuthManager.AuthManager__Unauthorized.selector;
        vm.expectRevert(err);

        manager.setAuthority(target, newAuthority);
    }

    // -------------------------------------------------------------------------
    // Test - Can Call

    function test_CanCall() public {
        vm.startPrank(owner);
        address target = address(managed);

        bytes4 inc = bytes4(0xd09de08a);
        bytes4 dec = bytes4(0x2baeceb7);

        // Should return false for all before any access is set.
        assertEq(manager.canCall(userA, target, inc), false);
        assertEq(manager.canCall(userB, target, inc), false);
        assertEq(manager.canCall(userC, target, inc), false);

        assertEq(manager.canCall(userA, target, dec), false);
        assertEq(manager.canCall(userB, target, dec), false);
        assertEq(manager.canCall(userC, target, dec), false);

        // Set user A's roles.
        manager.setUserRole(userA, 0, true);
        manager.setUserRole(userA, 1, true);

        // Set user B's roles.
        manager.setUserRole(userB, 1, true);
        manager.setUserRole(userB, 2, true);

        // Set user C's roles.
        manager.setUserRole(userC, 3, true);
        manager.setUserRole(userC, 4, true);

        // Set `increment` function access: 0 and 1.
        manager.setRoleAccess(target, inc, 0, true);
        manager.setRoleAccess(target, inc, 1, true);

        // Set `decrement` function access: 1, 2, and 3.
        manager.setRoleAccess(target, dec, 1, true);
        manager.setRoleAccess(target, dec, 2, true);
        manager.setRoleAccess(target, dec, 3, true);

        // The current state is now:
        // User A has access to Increment and Decrement.
        // User B has access to Increment and Decrement.
        // User C has access to Decrement.

        // Should return false if the target function is closed.
        manager.setFunctionClosed(target, inc, true);
        assertEq(manager.canCall(userA, target, inc), false);
        assertEq(manager.canCall(userB, target, inc), false);
        assertEq(manager.canCall(userC, target, inc), false);
        manager.setFunctionClosed(target, inc, false);

        manager.setFunctionClosed(target, dec, true);
        assertEq(manager.canCall(userA, target, dec), false);
        assertEq(manager.canCall(userB, target, dec), false);
        assertEq(manager.canCall(userC, target, dec), false);
        manager.setFunctionClosed(target, dec, false);

        // Should return true if the target function is public, regardless of
        // role.
        manager.setFunctionPublic(target, inc, true);
        assertEq(manager.canCall(userA, target, inc), true);
        assertEq(manager.canCall(userB, target, inc), true);
        assertEq(manager.canCall(userC, target, inc), true);
        manager.setFunctionPublic(target, inc, false);

        manager.setFunctionPublic(target, dec, true);
        assertEq(manager.canCall(userA, target, dec), true);
        assertEq(manager.canCall(userB, target, dec), true);
        assertEq(manager.canCall(userC, target, dec), true);
        manager.setFunctionPublic(target, dec, false);

        // Should correctly determine each user's access.
        assertEq(manager.canCall(userA, target, inc), true);
        assertEq(manager.canCall(userB, target, inc), true);
        assertEq(manager.canCall(userC, target, inc), false);

        assertEq(manager.canCall(userA, target, dec), true);
        assertEq(manager.canCall(userB, target, dec), true);
        assertEq(manager.canCall(userC, target, dec), true);

        vm.stopPrank();
    }
}
