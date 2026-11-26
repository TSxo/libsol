// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";
import { IOwned } from "@tsxo/libsol/auth/IOwned.sol";
import { OwnedHarness } from "test/harness/auth/OwnedHarness.sol";

interface TestEvents {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
}

contract OwnedTest is Test, TestEvents {
    // =========================================================================
    // State
    // =========================================================================

    OwnedHarness owned;
    address owner = makeAddr("owner");

    // =========================================================================
    // Set Up
    // =========================================================================

    function setUp() public {
        owned = new OwnedHarness(owner);
    }

    // =========================================================================
    // Test - Deployment
    // =========================================================================

    function test_Constructor_SetsOwner() public view {
        assertEq(owned.owner(), owner);
    }

    function test_RevertWhen_Constructor_OwnerIsZeroAddress() public {
        bytes4 err = IOwned.Owned__ZeroAddress.selector;
        vm.expectRevert(err);
        new OwnedHarness(address(0));
    }

    // =========================================================================
    // Test - Only Owner Modifier
    // =========================================================================

    function testFuzz_OnlyOwner_RestrictsAccess(address user) public {
        vm.assume(user != owner);

        bytes4 err = IOwned.Owned__Unauthorized.selector;
        vm.expectRevert(err);

        vm.prank(user);
        owned.setCount(1);

        vm.prank(owner);
        owned.setCount(1);
        assertEq(owned.count(), 1);
    }

    // =========================================================================
    // Test - Transfer Ownership
    // =========================================================================

    function testFuzz_TransferOwnership_UpdatesOwner(address newOwner) public {
        vm.expectEmit(true, true, false, false, address(owned));
        emit OwnershipTransferred(owner, newOwner);

        vm.prank(owner);
        owned.transferOwnership(newOwner);

        address updatedOwner = owned.owner();
        assertEq(updatedOwner, newOwner);
    }

    function test_TransferOwnership_AllowsZeroAddress() public {
        address newOwner = address(0);

        vm.expectEmit(true, true, false, false, address(owned));
        emit OwnershipTransferred(owner, newOwner);

        vm.prank(owner);
        owned.transferOwnership(newOwner);

        address updatedOwner = owned.owner();
        assertEq(updatedOwner, newOwner);
    }

    function testFuzz_RevertWhen_TransferOwnership_CallerIsNotOwner(address user) public {
        vm.assume(user != owner);

        bytes4 err = IOwned.Owned__Unauthorized.selector;
        vm.expectRevert(err);

        vm.prank(user);
        owned.transferOwnership(user);
    }
}
