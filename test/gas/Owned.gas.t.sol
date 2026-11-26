// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";

import { Ownable as OZOwnable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Owned } from "@tsxo/libsol/auth/Owned.sol";
import { Ownable as SoladyOwnable } from "solady/auth/Ownable.sol";

contract LibsolOwnedTarget is Owned {
    constructor(address initialOwner) {
        _initializeOwned(initialOwner);
    }

    function guarded() external onlyOwner { }
}

contract OZOwnedTarget is OZOwnable {
    constructor(address initialOwner) OZOwnable(initialOwner) { }

    function guarded() external onlyOwner { }
}

contract SoladyOwnedTarget is SoladyOwnable {
    constructor(address initialOwner) {
        _initializeOwner(initialOwner);
    }

    function guarded() external onlyOwner { }
}

/// @notice Single-owner access control: libsol `Owned` vs OpenZeppelin `Ownable`
/// vs Solady `Ownable`.
contract OwnedGasTest is Test {
    address owner = makeAddr("owner");
    address newOwner = makeAddr("new-owner");

    LibsolOwnedTarget libsol;
    OZOwnedTarget oz;
    SoladyOwnedTarget solady;

    function setUp() public {
        libsol = new LibsolOwnedTarget(owner);
        oz = new OZOwnedTarget(owner);
        solady = new SoladyOwnedTarget(owner);
    }

    function test_OnlyOwnerCall() public {
        vm.prank(owner);
        libsol.guarded();
        vm.snapshotGasLastFrame("Owned", "onlyOwner call / libsol");

        vm.prank(owner);
        oz.guarded();
        vm.snapshotGasLastFrame("Owned", "onlyOwner call / OpenZeppelin");

        vm.prank(owner);
        solady.guarded();
        vm.snapshotGasLastFrame("Owned", "onlyOwner call / Solady");
    }

    function test_TransferOwnership() public {
        vm.prank(owner);
        libsol.transferOwnership(newOwner);
        vm.snapshotGasLastFrame("Owned", "transferOwnership / libsol");

        vm.prank(owner);
        oz.transferOwnership(newOwner);
        vm.snapshotGasLastFrame("Owned", "transferOwnership / OpenZeppelin");

        vm.prank(owner);
        solady.transferOwnership(newOwner);
        vm.snapshotGasLastFrame("Owned", "transferOwnership / Solady");
    }
}
