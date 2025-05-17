pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";
import { IPausable } from "@tsxo/libsol/pause/IPausable.sol";
import { PausableMock } from "@tsxo/libsol/mocks/pause/PausableMock.sol";

interface TestEvents {
    event Paused(address indexed caller, bool enabled);
}

contract PausableTest is Test, TestEvents {
    // -------------------------------------------------------------------------
    // State

    PausableMock counter;

    // -------------------------------------------------------------------------
    // Set Up

    function setUp() public {
        counter = new PausableMock();
    }

    // -------------------------------------------------------------------------
    // Test - Pausing

    function test_Pausing() public {
        assertFalse(counter.isPaused());

        vm.expectEmit(true, false, false, true, address(counter));
        emit Paused(address(this), true);
        counter.setPaused(true);

        assertTrue(counter.isPaused());

        vm.expectEmit(true, false, false, true, address(counter));
        emit Paused(address(this), false);
        counter.setPaused(false);

        assertFalse(counter.isPaused());
    }

    // -------------------------------------------------------------------------
    // Test - Not Paused

    function test_NotPaused() public {
        assertFalse(counter.isPaused());
        assertEq(counter.count(), 0);

        counter.incrementWhenNotPaused();
        assertEq(counter.count(), 1);

        counter.setPaused(true);

        bytes4 err = IPausable.Pausable__PauseEnforced.selector;
        vm.expectRevert(err);
        counter.incrementWhenNotPaused();
    }

    // -------------------------------------------------------------------------
    // Test - Paused

    function test_Paused() public {
        assertFalse(counter.isPaused());
        assertEq(counter.count(), 0);

        bytes4 err = IPausable.Pausable__PauseExpected.selector;
        vm.expectRevert(err);
        counter.incrementWhenPaused();

        counter.setPaused(true);
        counter.incrementWhenPaused();
        assertEq(counter.count(), 1);
    }
}
