// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";

import { IOwned } from "@tsxo/libsol/auth/IOwned.sol";

import { IPauseManaged } from "@tsxo/libsol/pause/managed/IPauseManaged.sol";
import { IPauseManager } from "@tsxo/libsol/pause/managed/IPauseManager.sol";

import { PauseManagedHarness } from "test/harness/pause/PauseManagedHarness.sol";
import { PauseManagerHarness } from "test/harness/pause/PauseManagerHarness.sol";
import { RevertingTarget } from "test/mocks/AuthorityMock.sol";

interface TestEvents {
    event GlobalStatusUpdated(bool enabled);
    event TargetStatusUpdated(address indexed target, bool enabled);
    event PauseAuthorityUpdated(address indexed target, address indexed newAuthority);
}

contract PauseManagerTest is Test, TestEvents {
    // =========================================================================
    // State
    // =========================================================================

    address owner = makeAddr("owner");

    PauseManagerHarness manager;
    PauseManagedHarness managed;

    // =========================================================================
    // Set Up
    // =========================================================================

    function setUp() public {
        manager = new PauseManagerHarness(owner);
        managed = new PauseManagedHarness(address(manager));
    }

    // =========================================================================
    // Test - Set Target Paused
    // =========================================================================

    function test_SetTargetPaused_UpdatesTarget() public {
        address target = address(managed);

        vm.startPrank(owner);

        assertFalse(manager.isPaused(target));
        assertFalse(manager.isTargetPaused(target));

        vm.expectEmit(true, false, false, true, address(manager));
        emit TargetStatusUpdated(target, true);
        manager.setTargetPaused(target, true);

        assertTrue(manager.isPaused(target));
        assertTrue(manager.isTargetPaused(target));

        vm.stopPrank();
    }

    function testFuzz_SetTargetPaused_UpdatesTarget(address target, bool enabled) public {
        vm.startPrank(owner);

        assertFalse(manager.isPaused(target));
        assertFalse(manager.isTargetPaused(target));

        vm.expectEmit(true, false, false, true, address(manager));
        emit TargetStatusUpdated(target, enabled);
        manager.setTargetPaused(target, enabled);

        assertEq(manager.isPaused(target), enabled);
        assertEq(manager.isTargetPaused(target), enabled);

        vm.stopPrank();
    }

    function testFuzz_RevertWhen_SetTargetPaused_CallerIsNotOwner(address user, address target, bool enabled) public {
        vm.assume(user != owner);

        bytes4 err = IOwned.Owned__Unauthorized.selector;
        vm.expectRevert(err);

        vm.prank(user);
        manager.setTargetPaused(target, enabled);
    }

    // =========================================================================
    // Test - Set Globally Paused
    // =========================================================================

    function test_SetGloballyPaused_UpdatesGlobalFlag() public {
        address target = address(managed);

        vm.startPrank(owner);

        assertFalse(manager.isPaused(target));
        assertFalse(manager.isTargetPaused(target));
        assertFalse(manager.isGloballyPaused());

        vm.expectEmit(false, false, false, true, address(manager));
        emit GlobalStatusUpdated(true);
        manager.setGloballyPaused(true);

        assertTrue(manager.isPaused(target));
        assertFalse(manager.isTargetPaused(target));
        assertTrue(manager.isGloballyPaused());

        vm.stopPrank();
    }

    function testFuzz_RevertWhen_SetGloballyPaused_CallerIsNotOwner(address user, bool enabled) public {
        vm.assume(user != owner);

        bytes4 err = IOwned.Owned__Unauthorized.selector;
        vm.expectRevert(err);

        vm.prank(user);
        manager.setGloballyPaused(enabled);
    }

    // =========================================================================
    // Test - Set Pause Authority
    // =========================================================================

    function test_SetPauseAuthority_UpdatesTargetAuthority() public {
        address target = address(managed);
        address newAuthority = address(new PauseManagerHarness(owner));

        vm.expectEmit(true, true, false, false, address(manager));
        emit PauseAuthorityUpdated(target, newAuthority);

        vm.prank(owner);
        manager.setPauseAuthority(target, newAuthority);
        assertEq(managed.pauseAuthority(), newAuthority);
    }

    function testFuzz_RevertWhen_SetPauseAuthority_CallerIsNotOwner(address user) public {
        vm.assume(user != owner);
        vm.prank(user);

        address target = address(managed);
        address newAuthority = makeAddr("new-authority");

        bytes4 err = IOwned.Owned__Unauthorized.selector;
        vm.expectRevert(err);

        manager.setPauseAuthority(target, newAuthority);
    }

    // =========================================================================
    // Test - Set Pause Authority Failure Paths
    // =========================================================================

    function test_RevertWhen_SetPauseAuthority_TargetHasNoCode() public {
        vm.prank(owner);
        vm.expectRevert(IPauseManager.PauseManager__InvalidTarget.selector);
        manager.setPauseAuthority(makeAddr("no-code-target"), address(manager));
    }

    function test_RevertWhen_SetPauseAuthority_AuthorityHasNoCode() public {
        vm.prank(owner);
        vm.expectRevert(IPauseManaged.PauseManaged__InvalidAuthority.selector);
        manager.setPauseAuthority(address(managed), makeAddr("no-code-authority"));
    }

    function test_RevertWhen_SetPauseAuthority_TargetReverts() public {
        RevertingTarget target = new RevertingTarget();

        vm.prank(owner);
        vm.expectRevert(RevertingTarget.Refused.selector);
        manager.setPauseAuthority(address(target), address(manager));
    }
}
