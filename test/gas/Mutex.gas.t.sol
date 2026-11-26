// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";

import { ReentrancyGuard as OZReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {
    ReentrancyGuardTransient as OZReentrancyGuardTransient
} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import { Mutex } from "@tsxo/libsol/utils/Mutex.sol";
import { MutexTransient } from "@tsxo/libsol/utils/MutexTransient.sol";
import { ReentrancyGuard as SoladyReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";
import { ReentrancyGuardTransient as SoladyReentrancyGuardTransient } from "solady/utils/ReentrancyGuardTransient.sol";

contract LibsolMutexTarget is Mutex {
    constructor() {
        _initializeMutex();
    }

    function guarded() external lock { }
}

contract LibsolMutexTransientTarget is MutexTransient {
    function guarded() external lock { }
}

contract OZGuardTarget is OZReentrancyGuard {
    function guarded() external nonReentrant { }
}

contract OZGuardTransientTarget is OZReentrancyGuardTransient {
    function guarded() external nonReentrant { }
}

contract SoladyGuardTarget is SoladyReentrancyGuard {
    function guarded() external nonReentrant { }
}

contract SoladyGuardTransientTarget is SoladyReentrancyGuardTransient {
    function guarded() external nonReentrant { }

    /// @dev By default Solady uses transient storage only on chain ID 1 and
    /// falls back to storage elsewhere, including the test chain. Forcing it
    /// keeps the comparison transient-to-transient.
    function _useTransientReentrancyGuardOnlyOnMainnet() internal pure override returns (bool) {
        return false;
    }
}

/// @notice Reentrancy guards: libsol `Mutex` and `MutexTransient` vs the
/// OpenZeppelin and Solady guards, storage and transient variants.
contract MutexGasTest is Test {
    LibsolMutexTarget libsol;
    LibsolMutexTransientTarget libsolTransient;
    OZGuardTarget oz;
    OZGuardTransientTarget ozTransient;
    SoladyGuardTarget solady;
    SoladyGuardTransientTarget soladyTransient;

    function setUp() public {
        libsol = new LibsolMutexTarget();
        libsolTransient = new LibsolMutexTransientTarget();
        oz = new OZGuardTarget();
        ozTransient = new OZGuardTransientTarget();
        solady = new SoladyGuardTarget();
        soladyTransient = new SoladyGuardTransientTarget();
    }

    function test_GuardedCall_Storage() public {
        libsol.guarded();
        vm.snapshotGasLastFrame("Mutex", "guarded call, storage / libsol");

        oz.guarded();
        vm.snapshotGasLastFrame("Mutex", "guarded call, storage / OpenZeppelin");

        solady.guarded();
        vm.snapshotGasLastFrame("Mutex", "guarded call, storage / Solady");
    }

    function test_GuardedCall_Transient() public {
        libsolTransient.guarded();
        vm.snapshotGasLastFrame("Mutex", "guarded call, transient / libsol");

        ozTransient.guarded();
        vm.snapshotGasLastFrame("Mutex", "guarded call, transient / OpenZeppelin");

        soladyTransient.guarded();
        vm.snapshotGasLastFrame("Mutex", "guarded call, transient / Solady");
    }
}
