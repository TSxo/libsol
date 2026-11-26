// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { IOwned } from "@tsxo/libsol/auth/IOwned.sol";
import { IOwned2Step } from "@tsxo/libsol/auth/IOwned2Step.sol";

import { Owned2StepHarness } from "test/harness/auth/Owned2StepHarness.sol";
import { Owned2StepReferenceHarness } from "test/harness/auth/Owned2StepReferenceHarness.sol";

import { DifferentialBase } from "../DifferentialBase.sol";

/// @notice `Owned2Step` behaves exactly like the Solidity reference for any
/// sequence of proposals, acceptances, and renouncements by any of a few
/// actors.
contract Owned2StepDifferentialTest is DifferentialBase {
    enum Action {
        TransferOwnership,
        AcceptOwnership,
        RenounceOwnership,
        SetCount
    }

    /// @dev One fuzzed step. `caller` picks from the three real actors;
    /// `subject`, the proposed owner, from all four, including zero.
    struct Step {
        uint8 action;
        uint8 caller;
        uint8 subject;
        uint256 count;
    }

    address[4] actors;

    Owned2StepHarness actual;
    Owned2StepReferenceHarness expected;

    function setUp() public {
        actors = [makeAddr("actor-0"), makeAddr("actor-1"), makeAddr("actor-2"), address(0)];
        actual = new Owned2StepHarness(actors[0]);
        expected = new Owned2StepReferenceHarness(actors[0]);
    }

    function testFuzz_AnySequence_MatchesReference(Step[STEPS] calldata steps) public {
        for (uint256 i; i < STEPS; ++i) {
            Step calldata step = steps[i];
            Action action = Action(bound(step.action, 0, uint256(type(Action).max)));
            address caller = actors[bound(step.caller, 0, 2)];
            address subject = actors[bound(step.subject, 0, 3)];

            bytes memory data;
            if (action == Action.TransferOwnership) {
                data = abi.encodeCall(IOwned.transferOwnership, (subject));
            } else if (action == Action.AcceptOwnership) {
                data = abi.encodeCall(IOwned2Step.acceptOwnership, ());
            } else if (action == Action.RenounceOwnership) {
                data = abi.encodeCall(IOwned2Step.renounceOwnership, ());
            } else {
                data = abi.encodeCall(Owned2StepHarness.setCount, (step.count));
            }

            _callBoth(address(actual), address(expected), caller, data);

            assertEq(actual.owner(), expected.owner(), "owner");
            assertEq(actual.pendingOwner(), expected.pendingOwner(), "pending owner");
            assertEq(actual.count(), expected.count(), "count");
        }
    }
}
