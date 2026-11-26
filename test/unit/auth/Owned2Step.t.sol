// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";

import { IOwned } from "@tsxo/libsol/auth/IOwned.sol";
import { IOwned2Step } from "@tsxo/libsol/auth/IOwned2Step.sol";

import { Owned2StepHarness } from "test/harness/auth/Owned2StepHarness.sol";

interface TestEvents {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
}

contract Owned2StepTest is Test, TestEvents {
    address owner = makeAddr("owner");
    address newOwner = makeAddr("new-owner");
    address stranger = makeAddr("stranger");

    Owned2StepHarness owned;

    function setUp() public {
        owned = new Owned2StepHarness(owner);
    }

    // =========================================================================
    // Test - Two-Step Transfer
    // =========================================================================

    /// @dev Proposing records a pending owner but does not move ownership.
    function test_TransferOwnership_OnlyProposes() public {
        vm.expectEmit(address(owned));
        emit OwnershipTransferStarted(owner, newOwner);

        vm.prank(owner);
        owned.transferOwnership(newOwner);

        assertEq(owned.owner(), owner);
        assertEq(owned.pendingOwner(), newOwner);
    }

    function test_AcceptOwnership_MovesOwnership() public {
        vm.prank(owner);
        owned.transferOwnership(newOwner);

        vm.expectEmit(address(owned));
        emit OwnershipTransferred(owner, newOwner);

        vm.prank(newOwner);
        owned.acceptOwnership();

        assertEq(owned.owner(), newOwner);
        assertEq(owned.pendingOwner(), address(0));

        // The new owner has control; the old one does not.
        vm.prank(newOwner);
        owned.setCount(1);

        vm.prank(owner);
        vm.expectRevert(IOwned.Owned__Unauthorized.selector);
        owned.setCount(2);
    }

    function testFuzz_RevertWhen_AcceptOwnership_CallerIsNotPendingOwner(address caller) public {
        vm.assume(caller != newOwner);

        vm.prank(owner);
        owned.transferOwnership(newOwner);

        vm.prank(caller);
        vm.expectRevert(IOwned2Step.Owned2Step__NotPendingOwner.selector);
        owned.acceptOwnership();
    }

    function test_RevertWhen_AcceptOwnership_NoTransferIsPending() public {
        vm.prank(stranger);
        vm.expectRevert(IOwned2Step.Owned2Step__NotPendingOwner.selector);
        owned.acceptOwnership();
    }

    function testFuzz_RevertWhen_TransferOwnership_CallerIsNotOwner(address caller) public {
        vm.assume(caller != owner);

        vm.prank(caller);
        vm.expectRevert(IOwned.Owned__Unauthorized.selector);
        owned.transferOwnership(newOwner);
    }

    /// @dev A second proposal replaces the first; the first can no longer accept.
    function test_TransferOwnership_ReplacesPendingOwner() public {
        vm.startPrank(owner);
        owned.transferOwnership(newOwner);
        owned.transferOwnership(stranger);
        vm.stopPrank();

        assertEq(owned.pendingOwner(), stranger);

        vm.prank(newOwner);
        vm.expectRevert(IOwned2Step.Owned2Step__NotPendingOwner.selector);
        owned.acceptOwnership();
    }

    /// @dev Proposing the zero address cancels; it does not renounce.
    function test_TransferOwnershipToZero_CancelsPending() public {
        vm.startPrank(owner);
        owned.transferOwnership(newOwner);
        owned.transferOwnership(address(0));
        vm.stopPrank();

        assertEq(owned.owner(), owner);
        assertEq(owned.pendingOwner(), address(0));
    }

    // =========================================================================
    // Test - Renounce
    // =========================================================================

    function test_RenounceOwnership_ClearsOwnerAndPending() public {
        vm.prank(owner);
        owned.transferOwnership(newOwner);

        vm.expectEmit(address(owned));
        emit OwnershipTransferred(owner, address(0));

        vm.prank(owner);
        owned.renounceOwnership();

        assertEq(owned.owner(), address(0));
        assertEq(owned.pendingOwner(), address(0));

        // The old proposal cannot be accepted after renouncing.
        vm.prank(newOwner);
        vm.expectRevert(IOwned2Step.Owned2Step__NotPendingOwner.selector);
        owned.acceptOwnership();
    }

    function testFuzz_RevertWhen_RenounceOwnership_CallerIsNotOwner(address caller) public {
        vm.assume(caller != owner);

        vm.prank(caller);
        vm.expectRevert(IOwned.Owned__Unauthorized.selector);
        owned.renounceOwnership();
    }
}
