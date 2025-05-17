pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";

import { IPauseManaged } from "@tsxo/libsol/pause/managed/IPauseManaged.sol";
import { IPauseManager } from "@tsxo/libsol/pause/managed/IPauseManager.sol";

import { PauseManagedMock } from "@tsxo/libsol/mocks/pause/managed/PauseManagedMock.sol";
import { PauseManagerMock } from "@tsxo/libsol/mocks/pause/managed/PauseManagerMock.sol";

interface TestEvents {
    event PauseAuthorityUpdated(address indexed previousAuthority, address indexed newAuthority);
}

contract PauseManagedTest is Test, TestEvents {
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
    // Test - Initialization

    function test_Initialization() public view {
        assertEq(managed.pauseAuthority(), address(manager));
    }

    // -------------------------------------------------------------------------
    // Test - Set Authority

    function test_SetAuthorityRevertsOnUnauthorizedCalls() public {
        vm.prank(owner);

        bytes4 err = IPauseManaged.PauseManaged__Unauthorized.selector;
        vm.expectRevert(err);

        managed.setPauseAuthority(owner);
    }

    function test_SetAuthority() public {
        address target = address(managed);
        address newAuthority = address(0x9876);

        vm.expectEmit(true, true, false, false, address(managed));
        emit PauseAuthorityUpdated(address(manager), newAuthority);

        vm.prank(owner);
        manager.setPauseAuthority(target, newAuthority);
        assertEq(managed.pauseAuthority(), newAuthority);
    }

    // -------------------------------------------------------------------------
    // Test - Not Paused Modifier

    function test_NotPausedModifier() public {
        address target = address(managed);

        bytes4 err = IPauseManaged.PauseManaged__Paused.selector;

        // Check starting state.
        assertEq(managed.count(), 0);

        // Should allow for calls before any pause state is set.
        managed.increment();
        assertEq(managed.count(), 1);

        managed.decrement();
        assertEq(managed.count(), 0);

        // Should revert when globally paused.
        vm.prank(owner);
        manager.setGloballyPaused(true);

        vm.expectRevert(err);
        managed.increment();

        vm.expectRevert(err);
        managed.decrement();

        // Should revert when the target is paused.
        vm.startPrank(owner);
        manager.setGloballyPaused(false);
        manager.setTargetPaused(target, true);
        vm.stopPrank();

        vm.expectRevert(err);
        managed.increment();

        vm.expectRevert(err);
        managed.decrement();
    }
}
