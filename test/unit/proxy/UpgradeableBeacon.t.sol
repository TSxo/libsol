// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";

import { IOwned } from "@tsxo/libsol/auth/IOwned.sol";
import { IUpgradeableBeacon } from "@tsxo/libsol/proxy/beacon/IUpgradeableBeacon.sol";
import { UpgradeableBeacon } from "@tsxo/libsol/proxy/beacon/UpgradeableBeacon.sol";

import { UpgradeableBeaconHarness } from "test/harness/proxy/UpgradeableBeaconHarness.sol";
import { CounterTarget } from "test/mocks/CounterTarget.sol";

interface TestEvents {
    event Upgraded(address indexed implementation);
}

contract UpgradeableBeaconTest is Test, TestEvents {
    address owner = makeAddr("owner");
    address user = makeAddr("user");

    address implementation;
    address nextImplementation;
    UpgradeableBeacon beacon;

    function setUp() public {
        implementation = address(new CounterTarget());
        nextImplementation = address(new CounterTarget());
        beacon = new UpgradeableBeaconHarness(owner, implementation);
    }

    // =========================================================================
    // Constructor
    // =========================================================================

    function test_Constructor_SetsOwnerAndImplementation() public {
        vm.expectEmit(true, false, false, false);
        emit Upgraded(implementation);
        UpgradeableBeacon fresh = new UpgradeableBeaconHarness(owner, implementation);

        assertEq(fresh.owner(), owner);
        assertEq(fresh.implementation(), implementation);
    }

    function testFuzz_RevertWhen_Constructor_ImplementationHasNoCode(address account) public {
        vm.assume(account.code.length == 0);

        vm.expectRevert(IUpgradeableBeacon.UpgradeableBeacon__InvalidImplementation.selector);
        new UpgradeableBeaconHarness(owner, account);
    }

    // =========================================================================
    // upgradeTo
    // =========================================================================

    function test_UpgradeTo_SetsImplementationAndEmits() public {
        vm.expectEmit(true, false, false, false, address(beacon));
        emit Upgraded(nextImplementation);

        vm.prank(owner);
        beacon.upgradeTo(nextImplementation);

        assertEq(beacon.implementation(), nextImplementation);
    }

    function testFuzz_RevertWhen_UpgradeTo_CallerIsNotOwner(address caller) public {
        vm.assume(caller != owner);

        vm.expectRevert(IOwned.Owned__Unauthorized.selector);
        vm.prank(caller);
        beacon.upgradeTo(nextImplementation);
    }

    function testFuzz_RevertWhen_UpgradeTo_ImplementationHasNoCode(address account) public {
        vm.assume(account.code.length == 0);

        vm.expectRevert(IUpgradeableBeacon.UpgradeableBeacon__InvalidImplementation.selector);
        vm.prank(owner);
        beacon.upgradeTo(account);
    }

    function test_UpgradeTo_FollowsOwnershipTransfer() public {
        vm.prank(owner);
        beacon.transferOwnership(user);

        vm.expectRevert(IOwned.Owned__Unauthorized.selector);
        vm.prank(owner);
        beacon.upgradeTo(nextImplementation);

        vm.prank(user);
        beacon.upgradeTo(nextImplementation);
        assertEq(beacon.implementation(), nextImplementation);
    }
}
