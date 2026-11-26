// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Mutex } from "@tsxo/libsol/utils/Mutex.sol";
import { MutexAttack } from "test/mocks/MutexAttack.sol";

contract MutexHarness is Mutex {
    uint256 private _count;

    constructor() {
        _initializeMutex();
    }

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
}

