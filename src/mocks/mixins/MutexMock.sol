// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { Mutex } from "@tsxo/libsol/mixins/Mutex.sol";

contract MutexMock is Mutex {
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

    function isLocked() external view returns (bool) {
        return _isLocked();
    }
}

contract MutexAttack {
    error Failed();

    function execute(bytes4 selector) external {
        (bool success,) = msg.sender.call(abi.encodeWithSelector(selector));

        if (!success) revert Failed();
    }
}
