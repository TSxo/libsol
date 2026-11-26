// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";

import { Initializable as OZInitializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { Initializable } from "@tsxo/libsol/proxy/Initializable.sol";
import { Initializable as SoladyInitializable } from "solady/utils/Initializable.sol";

contract LibsolInitializableTarget is Initializable {
    uint256 public value;

    function initialize(uint256 newValue) external initializer {
        value = newValue;
    }

    function reinitialize(uint256 newValue) external reinitializer(2) {
        value = newValue;
    }
}

contract OZInitializableTarget is OZInitializable {
    uint256 public value;

    function initialize(uint256 newValue) external initializer {
        value = newValue;
    }

    function reinitialize(uint256 newValue) external reinitializer(2) {
        value = newValue;
    }
}

contract SoladyInitializableTarget is SoladyInitializable {
    uint256 public value;

    function initialize(uint256 newValue) external initializer {
        value = newValue;
    }

    function reinitialize(uint256 newValue) external reinitializer(2) {
        value = newValue;
    }
}

/// @notice Initializer guards: libsol `Initializable` vs OpenZeppelin
/// `Initializable` vs Solady `Initializable`. Each initializer stores one value.
contract InitializableGasTest is Test {
    LibsolInitializableTarget libsol;
    OZInitializableTarget oz;
    SoladyInitializableTarget solady;

    function setUp() public {
        libsol = new LibsolInitializableTarget();
        oz = new OZInitializableTarget();
        solady = new SoladyInitializableTarget();
    }

    function test_Initialize() public {
        libsol.initialize(1);
        vm.snapshotGasLastFrame("Initializable", "initialize / libsol");

        oz.initialize(1);
        vm.snapshotGasLastFrame("Initializable", "initialize / OpenZeppelin");

        solady.initialize(1);
        vm.snapshotGasLastFrame("Initializable", "initialize / Solady");
    }

    function test_Reinitialize() public {
        libsol.initialize(1);
        oz.initialize(1);
        solady.initialize(1);

        libsol.reinitialize(2);
        vm.snapshotGasLastFrame("Initializable", "reinitialize / libsol");

        oz.reinitialize(2);
        vm.snapshotGasLastFrame("Initializable", "reinitialize / OpenZeppelin");

        solady.reinitialize(2);
        vm.snapshotGasLastFrame("Initializable", "reinitialize / Solady");
    }
}
