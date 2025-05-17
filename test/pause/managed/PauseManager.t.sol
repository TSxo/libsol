pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";

import { IPauseManaged } from "@tsxo/libsol/pause/managed/IPauseManaged.sol";
import { IPauseManager } from "@tsxo/libsol/pause/managed/IPauseManager.sol";

import { PauseManagedMock } from "@tsxo/libsol/mocks/pause/managed/PauseManagedMock.sol";
import { PauseManagerMock } from "@tsxo/libsol/mocks/pause/managed/PauseManagerMock.sol";

interface TestEvents {
    event GlobalStatusUpdated(bool enabled);
    event TargetStatusUpdated(address indexed target, bool enabled);
    event PauseAuthorityUpdated(address indexed target, address indexed newAuthority);
}

contract PauseManagerTest is Test, TestEvents {
    // -------------------------------------------------------------------------
    // State

    address constant owner = address(0x1234);

    PauseManagerMock manager;
    PauseManagedMock managed;

    // -------------------------------------------------------------------------
    // Set Up

    function setUp() public {
        manager = new PauseManagerMock(owner);
        managed = new PauseManagedMock(address(manager));
    }

    // -------------------------------------------------------------------------
    // Test - Set Target Paused

    function test_SetTargetPaused() public {
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

    function testFuzz_SetTargetPaused(address target, bool enabled) public {
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

    function testFuzz_OnlyOwnerCanSetTargetPaused(address user, address target, bool enabled) public {
        vm.assume(user != owner);

        bytes4 err = IPauseManager.PauseManager__Unauthorized.selector;
        vm.expectRevert(err);

        vm.prank(user);
        manager.setTargetPaused(target, enabled);
    }

    // -------------------------------------------------------------------------
    // Test - Set Globally Paused

    function test_SetGloballyPaused() public {
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

    function testFuzz_OnlyOwnerCanSetGloballyPaused(address user, bool enabled) public {
        vm.assume(user != owner);

        bytes4 err = IPauseManager.PauseManager__Unauthorized.selector;
        vm.expectRevert(err);

        vm.prank(user);
        manager.setGloballyPaused(enabled);
    }

    // -------------------------------------------------------------------------
    // Test - Set Pause Authority

    function test_SetPauseAuthority() public {
        address target = address(managed);
        address newAuthority = address(new PauseManagerMock(owner));

        vm.expectEmit(true, true, false, false, address(manager));
        emit PauseAuthorityUpdated(target, newAuthority);

        vm.prank(owner);
        manager.setPauseAuthority(target, newAuthority);
        assertEq(managed.pauseAuthority(), newAuthority);
    }

    function testFuzz_OnlyOwnerCanSetAuthority(address user) public {
        vm.assume(user != owner);
        vm.prank(user);

        address target = address(managed);
        address newAuthority = address(0x9876);

        bytes4 err = IPauseManager.PauseManager__Unauthorized.selector;
        vm.expectRevert(err);

        manager.setPauseAuthority(target, newAuthority);
    }
}
