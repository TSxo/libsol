pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";
import { IOwned } from "@tsxo/libsol/auth/IOwned.sol";
import { OwnedImpl } from "@tsxo/libsol/mocks/auth/OwnedImpl.sol";

interface TestEvents {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
}

contract OwnedTest is Test, TestEvents {
    // -------------------------------------------------------------------------
    // State

    OwnedImpl owned;
    address constant owner = address(0x1234);

    // -------------------------------------------------------------------------
    // Set Up

    function setUp() public {
        owned = new OwnedImpl(owner);
    }

    // -------------------------------------------------------------------------
    // Test - Deployment

    function test_OwnerIsSetOnConstruction() public view {
        assertEq(owned.owner(), owner);
    }

    function test_RevertsOnConstructionWithZeroAddress() public {
        bytes4 err = IOwned.Owned__ZeroAddress.selector;
        vm.expectRevert(err);
        new OwnedImpl(address(0));
    }

    // -------------------------------------------------------------------------
    // Test - Only Owner Modifier

    function testFuzz_RestrictsAccess(address user) public {
        vm.assume(user != owner);

        bytes4 err = IOwned.Owned__Unauthorized.selector;
        vm.expectRevert(err);

        vm.prank(user);
        owned.setCount(1);

        vm.prank(owner);
        owned.setCount(1);
        assertEq(owned.count(), 1);
    }

    // -------------------------------------------------------------------------
    // Test - Transfer Ownership

    function testFuzz_OwnerCanTransferOwnership(address newOwner) public {
        vm.expectEmit(true, true, false, false, address(owned));
        emit OwnershipTransferred(owner, newOwner);

        vm.prank(owner);
        owned.transferOwnership(newOwner);

        address updatedOwner = owned.owner();
        assertEq(updatedOwner, newOwner);
    }

    function test_AllowsTransferOwnershipToZeroAddress() public {
        address newOwner = address(0);

        vm.expectEmit(true, true, false, false, address(owned));
        emit OwnershipTransferred(owner, newOwner);

        vm.prank(owner);
        owned.transferOwnership(newOwner);

        address updatedOwner = owned.owner();
        assertEq(updatedOwner, newOwner);
    }

    function testFuzz_OnlyOwnerCanTransferOwnership(address user) public {
        vm.assume(user != owner);

        bytes4 err = IOwned.Owned__Unauthorized.selector;
        vm.expectRevert(err);

        vm.prank(user);
        owned.transferOwnership(user);
    }
}
