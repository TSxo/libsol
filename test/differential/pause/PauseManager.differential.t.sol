// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { IPauseAuthority } from "@tsxo/libsol/pause/managed/IPauseAuthority.sol";
import { IPauseManager } from "@tsxo/libsol/pause/managed/IPauseManager.sol";

import { PauseManagerHarness } from "test/harness/pause/PauseManagerHarness.sol";
import { PauseManagerReferenceHarness } from "test/harness/pause/PauseManagerReferenceHarness.sol";
import { ScriptedMock } from "test/mocks/ScriptedMock.sol";

import { DifferentialBase } from "../DifferentialBase.sol";

/// @notice The assembly `PauseManager` matches the Solidity reference for any
/// sequence of pause changes and pause authority hand-overs, by the owner or
/// anyone else.
contract PauseManagerDifferentialTest is DifferentialBase {
    enum Action {
        SetTargetPaused,
        SetGloballyPaused,
        SetPauseAuthority
    }

    /// @dev One fuzzed step. `target` and `newAuthority` pick from `targets`.
    struct Step {
        uint8 action;
        bool byOwner;
        uint8 target;
        bool enabled;
        uint8 newAuthority;
    }

    address owner = makeAddr("owner");
    address user = makeAddr("user");

    PauseManagerHarness actual;
    PauseManagerReferenceHarness expected;

    /// @dev Targets: some accept `setPauseAuthority`, some return data, revert,
    /// or have no code.
    address[] targets;

    function setUp() public {
        actual = new PauseManagerHarness(owner);
        expected = new PauseManagerReferenceHarness(owner);

        targets.push(address(new ScriptedMock(false, "")));
        targets.push(address(new ScriptedMock(false, "")));
        targets.push(address(new ScriptedMock(false, abi.encode(true))));
        targets.push(address(new ScriptedMock(true, abi.encodeWithSignature("Error(string)", "nope"))));
        targets.push(address(new ScriptedMock(true, "")));
        targets.push(makeAddr("eoa"));
        targets.push(address(0));
    }

    function testFuzz_AnySequence_MatchesReference(Step[STEPS] calldata steps) public {
        for (uint256 i; i < STEPS; ++i) {
            Step calldata step = steps[i];
            Action action = Action(bound(step.action, 0, uint256(type(Action).max)));
            address caller = step.byOwner ? owner : user;
            address target = targets[bound(step.target, 0, targets.length - 1)];

            bytes memory data;
            if (action == Action.SetTargetPaused) {
                data = abi.encodeCall(IPauseManager.setTargetPaused, (target, step.enabled));
            } else if (action == Action.SetGloballyPaused) {
                data = abi.encodeCall(IPauseManager.setGloballyPaused, (step.enabled));
            } else {
                address newAuthority = targets[bound(step.newAuthority, 0, targets.length - 1)];
                data = abi.encodeCall(IPauseAuthority.setPauseAuthority, (target, newAuthority));
            }

            _callBoth(address(actual), address(expected), caller, data);

            assertEq(actual.isGloballyPaused(), expected.isGloballyPaused(), "globally paused");
            for (uint256 j; j < targets.length; ++j) {
                assertEq(actual.isTargetPaused(targets[j]), expected.isTargetPaused(targets[j]), "target paused");
                assertEq(actual.isPaused(targets[j]), expected.isPaused(targets[j]), "paused");
            }
        }
    }
}
