// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step as OZOwnable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Owned2Step } from "@tsxo/libsol/auth/Owned2Step.sol";
import { Ownable as SoladyOwnable } from "solady/auth/Ownable.sol";

contract LibsolOwned2StepTarget is Owned2Step {
    constructor(address initialOwner) {
        _initializeOwned(initialOwner);
    }
}

contract OZOwnable2StepTarget is OZOwnable2Step {
    constructor(address initialOwner) Ownable(initialOwner) { }
}

contract SoladyOwnableTarget is SoladyOwnable {
    constructor(address initialOwner) {
        _initializeOwner(initialOwner);
    }
}

/// @notice Two-step ownership transfer: libsol `Owned2Step` vs OpenZeppelin
/// `Ownable2Step` vs Solady `Ownable`'s handover.
///
/// @dev Solady's handover runs the other way round: the new owner requests it
/// (`requestOwnershipHandover`) and the owner completes it
/// (`completeOwnershipHandover`). Its request also records an expiry.
contract Owned2StepGasTest is Test {
    address owner = makeAddr("owner");
    address newOwner = makeAddr("new-owner");

    LibsolOwned2StepTarget libsol;
    OZOwnable2StepTarget oz;
    SoladyOwnableTarget solady;

    function setUp() public {
        libsol = new LibsolOwned2StepTarget(owner);
        oz = new OZOwnable2StepTarget(owner);
        solady = new SoladyOwnableTarget(owner);
    }

    function test_StartTransfer() public {
        vm.prank(owner);
        libsol.transferOwnership(newOwner);
        vm.snapshotGasLastFrame("Owned2Step", "start transfer / libsol");

        vm.prank(owner);
        oz.transferOwnership(newOwner);
        vm.snapshotGasLastFrame("Owned2Step", "start transfer / OpenZeppelin");

        vm.prank(newOwner);
        solady.requestOwnershipHandover();
        vm.snapshotGasLastFrame("Owned2Step", "start transfer / Solady");
    }

    function test_CompleteTransfer() public {
        vm.prank(owner);
        libsol.transferOwnership(newOwner);
        vm.prank(owner);
        oz.transferOwnership(newOwner);
        vm.prank(newOwner);
        solady.requestOwnershipHandover();

        vm.prank(newOwner);
        libsol.acceptOwnership();
        vm.snapshotGasLastFrame("Owned2Step", "complete transfer / libsol");

        vm.prank(newOwner);
        oz.acceptOwnership();
        vm.snapshotGasLastFrame("Owned2Step", "complete transfer / OpenZeppelin");

        vm.prank(owner);
        solady.completeOwnershipHandover(newOwner);
        vm.snapshotGasLastFrame("Owned2Step", "complete transfer / Solady");
    }
}
