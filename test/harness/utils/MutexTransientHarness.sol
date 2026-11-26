// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { MutexTransient } from "@tsxo/libsol/utils/MutexTransient.sol";
import { MutexAttack } from "test/mocks/MutexAttack.sol";

contract MutexTransientHarness is MutexTransient {
    uint256 private _count;

    function increment() public lock {
        _count++;
    }

    function count() public view whenUnlocked returns (uint256) {
        return _count;
    }

    function unguardedToGuarded() external {
        increment();
    }

    function guardedToGuarded() external lock {
        increment();
    }

    function unguardedToGuardedRead() external view {
        count();
    }

    function guardedToGuardedRead() external lock {
        count();
    }

    function unguardedToExternal(MutexAttack attacker) external {
        attacker.execute(this.increment.selector);
    }

    function guardedToExternal(MutexAttack attacker) external lock {
        attacker.execute(this.increment.selector);
    }

    function exposed_isLocked() external view returns (bool) {
        return _isLocked();
    }

    /// @dev Reads transient `slot` while the lock is held, so a test can check
    /// which slot the lock uses.
    function probeLockedSlot(bytes32 slot) external lock returns (uint256 value) {
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }
}
