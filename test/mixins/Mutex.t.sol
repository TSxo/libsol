pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";
import { Mutex } from "@tsxo/libsol/mixins/Mutex.sol";
import { MutexImpl, MutexAttack } from "@tsxo/libsol/mocks/mixins/MutexImpl.sol";

contract MutextTest is Test {
    // -------------------------------------------------------------------------
    // State

    MutexImpl mutex;
    MutexAttack attacker;

    // -------------------------------------------------------------------------
    // Set Up

    function setUp() public {
        mutex = new MutexImpl();
        attacker = new MutexAttack();
    }

    // -------------------------------------------------------------------------
    // Test - Initialization

    function test_IsUnlockedByDefault() public view {
        assertFalse(mutex.isLocked());
    }

    // -------------------------------------------------------------------------
    // Test - Guards

    function test_UnguardedCanCallGuarded() public {
        assertEq(mutex.count(), 0);
        mutex.unguardedToGuarded();
        assertEq(mutex.count(), 1);
    }

    function test_GuardedCannotCallGuarded() public {
        bytes4 err = Mutex.Mutex__Locked.selector;
        vm.expectRevert(err);

        mutex.guardedToGuarded();
    }

    function test_UnguardedCanCallGuardedRead() public view {
        mutex.unguardedToGuardedRead();
    }

    function test_GuardedCannotCallGuardedRead() public {
        bytes4 err = Mutex.Mutex__Locked.selector;
        vm.expectRevert(err);

        mutex.guardedToGuardedRead();
    }

    function test_UnguardedExternalCallCanReenter() public {
        assertEq(mutex.count(), 0);
        mutex.unguardedToExternal(attacker);
        assertEq(mutex.count(), 1);
    }

    function test_GuardedExternalCallPreventsReentrancy() public {
        bytes4 err = MutexAttack.Failed.selector;
        vm.expectRevert(err);

        mutex.guardedToExternal(attacker);
    }
}
