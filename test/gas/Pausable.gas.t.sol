// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";

import { Pausable as OZPausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Pausable } from "@tsxo/libsol/pause/Pausable.sol";

contract LibsolPausableTarget is Pausable {
    function pause() external {
        _setPaused(true);
    }

    function guarded() external notPaused { }
}

contract OZPausableTarget is OZPausable {
    function pause() external {
        _pause();
    }

    function guarded() external whenNotPaused { }
}

/// @notice Local pause switch: libsol `Pausable` vs OpenZeppelin `Pausable`.
/// Solady has no equivalent.
contract PausableGasTest is Test {
    LibsolPausableTarget libsol;
    OZPausableTarget oz;

    function setUp() public {
        libsol = new LibsolPausableTarget();
        oz = new OZPausableTarget();
    }

    function test_NotPausedCall() public {
        libsol.guarded();
        vm.snapshotGasLastFrame("Pausable", "notPaused call / libsol");

        oz.guarded();
        vm.snapshotGasLastFrame("Pausable", "notPaused call / OpenZeppelin");
    }

    function test_Pause() public {
        libsol.pause();
        vm.snapshotGasLastFrame("Pausable", "pause / libsol");

        oz.pause();
        vm.snapshotGasLastFrame("Pausable", "pause / OpenZeppelin");
    }
}
