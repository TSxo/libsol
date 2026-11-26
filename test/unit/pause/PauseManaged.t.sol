// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";

import { IPauseManaged } from "@tsxo/libsol/pause/managed/IPauseManaged.sol";
import { IPauseManager } from "@tsxo/libsol/pause/managed/IPauseManager.sol";

import { PauseManagedHarness } from "test/harness/pause/PauseManagedHarness.sol";
import { PauseManagerHarness } from "test/harness/pause/PauseManagerHarness.sol";
import { AuthorityMock } from "test/mocks/AuthorityMock.sol";

interface TestEvents {
    event PauseAuthorityUpdated(address indexed previousAuthority, address indexed newAuthority);
}

abstract contract PauseManagedTestBase is Test, TestEvents {
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
}

contract PauseManagedSetAuthorityTest is PauseManagedTestBase {
    function test_Constructor_SetsPauseAuthority() public view {
        assertEq(managed.pauseAuthority(), address(manager));
    }

    function test_RevertWhen_Constructor_AuthorityHasNoCode() public {
        vm.expectRevert(IPauseManaged.PauseManaged__InvalidAuthority.selector);
        new PauseManagedHarness(makeAddr("no-code-authority"));
    }

    function test_SetPauseAuthority_UpdatesAuthority() public {
        address target = address(managed);
        address newAuthority = address(new PauseManagerHarness(owner));

        vm.expectEmit(true, true, false, false, address(managed));
        emit PauseAuthorityUpdated(address(manager), newAuthority);

        vm.prank(owner);
        manager.setPauseAuthority(target, newAuthority);
        assertEq(managed.pauseAuthority(), newAuthority);
    }

    function test_RevertWhen_SetPauseAuthority_CallerIsNotAuthority() public {
        vm.prank(owner);

        bytes4 err = IPauseManaged.PauseManaged__Unauthorized.selector;
        vm.expectRevert(err);

        managed.setPauseAuthority(owner);
    }
}

contract PauseManagedNotPausedTest is PauseManagedTestBase {
    function test_NotPaused_AllowsCallsWhenNothingIsPaused() public {
        managed.increment();
        managed.decrement();

        assertEq(managed.count(), 0);
    }

    function test_RevertWhen_NotPaused_GloballyPaused() public {
        vm.prank(owner);
        manager.setGloballyPaused(true);

        vm.expectRevert(IPauseManaged.PauseManaged__Paused.selector);
        managed.increment();
    }

    function test_RevertWhen_NotPaused_TargetIsPaused() public {
        vm.prank(owner);
        manager.setTargetPaused(address(managed), true);

        vm.expectRevert(IPauseManaged.PauseManaged__Paused.selector);
        managed.increment();
    }

    /// @dev Pausing one target leaves others running.
    function test_NotPaused_IgnoresOtherTargetsBeingPaused() public {
        vm.prank(owner);
        manager.setTargetPaused(makeAddr("other-target"), true);

        managed.increment();
        assertEq(managed.count(), 1);
    }

    /// @dev Unpausing restores access, with no change to the target.
    function test_NotPaused_AllowsCallsAgainAfterUnpausing() public {
        vm.startPrank(owner);
        manager.setGloballyPaused(true);
        manager.setGloballyPaused(false);
        vm.stopPrank();

        managed.increment();
        assertEq(managed.count(), 1);
    }

    function test_RevertWhen_NotPaused_AuthorityReverts() public {
        AuthorityMock authority = new AuthorityMock();
        PauseManagedHarness target = new PauseManagedHarness(address(authority));
        authority.configure(AuthorityMock.Mode.Revert, 0);

        vm.expectRevert(AuthorityMock.Rejected.selector);
        target.increment();
    }

    function test_RevertWhen_NotPaused_ReplyIsMalformed() public {
        AuthorityMock authority = new AuthorityMock();
        PauseManagedHarness target = new PauseManagedHarness(address(authority));
        authority.configure(AuthorityMock.Mode.ReturnShort, 0);

        vm.expectRevert(IPauseManaged.PauseManaged__InvalidAuthority.selector);
        target.increment();
    }

    /// @dev Any non-zero word counts as paused, so malformed answers fail closed.
    function testFuzz_NotPaused_AnyNonZeroWordIsPaused(uint256 word) public {
        AuthorityMock authority = new AuthorityMock();
        PauseManagedHarness target = new PauseManagedHarness(address(authority));
        authority.configure(AuthorityMock.Mode.ReturnWord, word);

        if (word != 0) vm.expectRevert(IPauseManaged.PauseManaged__Paused.selector);
        target.increment();
    }

    /// @dev `notPaused` works on view functions.
    function test_NotPaused_OnViewFunction() public {
        assertEq(managed.countWhenNotPaused(), 0);

        vm.prank(owner);
        manager.setGloballyPaused(true);

        vm.expectRevert(IPauseManaged.PauseManaged__Paused.selector);
        managed.countWhenNotPaused();
    }
}
