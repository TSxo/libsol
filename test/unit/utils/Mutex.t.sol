// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";

import { Mutex } from "@tsxo/libsol/utils/Mutex.sol";
import { MutexTransient } from "@tsxo/libsol/utils/MutexTransient.sol";

import { IMutexHarness } from "test/harness/utils/IMutexHarness.sol";
import { MutexHarness } from "test/harness/utils/MutexHarness.sol";
import { MutexTransientHarness } from "test/harness/utils/MutexTransientHarness.sol";
import { MutexAttack } from "test/mocks/MutexAttack.sol";

/// @notice The guard behaviour both mutexes must share. Each concrete suite
/// below supplies the implementation.
abstract contract MutexTestBase is Test {
    // =========================================================================
    // State
    // =========================================================================

    IMutexHarness mutex;
    MutexAttack attacker;

    // =========================================================================
    // Set Up
    // =========================================================================

    function _deploy() internal virtual returns (IMutexHarness);

    function setUp() public {
        mutex = _deploy();
        attacker = new MutexAttack();
    }

    // =========================================================================
    // Test - Initialization
    // =========================================================================

    function test_Mutex_IsUnlockedByDefault() public view {
        assertFalse(mutex.exposed_isLocked());
    }

    // =========================================================================
    // Test - Guards
    // =========================================================================

    function test_Lock_AllowsCallFromUnguarded() public {
        assertEq(mutex.count(), 0);
        mutex.unguardedToGuarded();
        assertEq(mutex.count(), 1);
    }

    function test_RevertWhen_Lock_CalledFromGuarded() public {
        vm.expectRevert(Mutex.Mutex__Locked.selector);
        mutex.guardedToGuarded();
    }

    function test_WhenUnlocked_AllowsCallFromUnguarded() public view {
        mutex.unguardedToGuardedRead();
    }

    function test_RevertWhen_WhenUnlocked_CalledFromGuarded() public {
        vm.expectRevert(Mutex.Mutex__Locked.selector);
        mutex.guardedToGuardedRead();
    }

    function test_Unguarded_CanBeReentered() public {
        assertEq(mutex.count(), 0);
        mutex.unguardedToExternal(attacker);
        assertEq(mutex.count(), 1);
    }

    function test_RevertWhen_Lock_Reentered() public {
        vm.expectRevert(MutexAttack.Failed.selector);
        mutex.guardedToExternal(attacker);
    }

    /// @dev The lock is released after a guarded call, so a second one in the
    /// same transaction succeeds.
    function test_Lock_IsReleasedAfterCall() public {
        mutex.increment();
        assertFalse(mutex.exposed_isLocked());

        mutex.increment();
        assertEq(mutex.count(), 2);
    }
}

contract MutexTest is MutexTestBase {
    function _deploy() internal override returns (IMutexHarness) {
        return IMutexHarness(address(new MutexHarness()));
    }
}

contract MutexTransientTest is MutexTestBase {
    function _deploy() internal override returns (IMutexHarness) {
        return IMutexHarness(address(new MutexTransientHarness()));
    }

    /// @dev Both mutexes raise the same error, so they are interchangeable.
    function test_MutexTransient_SharesErrorWithMutex() public pure {
        assertEq(MutexTransient.Mutex__Locked.selector, Mutex.Mutex__Locked.selector);
    }

    /// @dev The lock never touches persistent storage.
    function test_MutexTransient_UsesNoStorage() public {
        vm.record();
        mutex.increment();
        (, bytes32[] memory writes) = vm.accesses(address(mutex));

        // Only `_count` is written.
        assertEq(writes.length, 1);
        assertEq(writes[0], bytes32(0));
    }
}
