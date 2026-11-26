// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";
import { IPausable } from "@tsxo/libsol/pause/IPausable.sol";
import { PausableHarness } from "test/harness/pause/PausableHarness.sol";

interface TestEvents {
    event Paused(address indexed caller, bool enabled);
}

contract PausableTest is Test, TestEvents {
    // =========================================================================
    // State
    // =========================================================================

    PausableHarness counter;

    // =========================================================================
    // Set Up
    // =========================================================================

    function setUp() public {
        counter = new PausableHarness();
    }

    // =========================================================================
    // Test - Pausing
    // =========================================================================

    function test_SetPaused_UpdatesStateAndEmits() public {
        assertFalse(counter.isPaused());

        vm.expectEmit(true, false, false, true, address(counter));
        emit Paused(address(this), true);
        counter.exposed_setPaused(true);

        assertTrue(counter.isPaused());

        vm.expectEmit(true, false, false, true, address(counter));
        emit Paused(address(this), false);
        counter.exposed_setPaused(false);

        assertFalse(counter.isPaused());
    }

    // =========================================================================
    // Test - Not Paused
    // =========================================================================

    function test_RevertWhen_NotPaused_ContractIsPaused() public {
        assertFalse(counter.isPaused());
        assertEq(counter.count(), 0);

        counter.incrementWhenNotPaused();
        assertEq(counter.count(), 1);

        counter.exposed_setPaused(true);

        bytes4 err = IPausable.Pausable__PauseEnforced.selector;
        vm.expectRevert(err);
        counter.incrementWhenNotPaused();
    }

    // =========================================================================
    // Test - Paused
    // =========================================================================

    function test_RevertWhen_Paused_ContractIsUnpaused() public {
        assertFalse(counter.isPaused());
        assertEq(counter.count(), 0);

        bytes4 err = IPausable.Pausable__PauseExpected.selector;
        vm.expectRevert(err);
        counter.incrementWhenPaused();

        counter.exposed_setPaused(true);
        counter.incrementWhenPaused();
        assertEq(counter.count(), 1);
    }

    // =========================================================================
    // Test - View Functions
    // =========================================================================

    /// @dev `notPaused` and `paused` work on view functions.
    function test_Modifiers_WorkOnViewFunctions() public {
        assertEq(counter.countWhenNotPaused(), 0);
        vm.expectRevert(IPausable.Pausable__PauseExpected.selector);
        counter.countWhenPaused();

        counter.exposed_setPaused(true);

        assertEq(counter.countWhenPaused(), 0);
        vm.expectRevert(IPausable.Pausable__PauseEnforced.selector);
        counter.countWhenNotPaused();
    }
}
