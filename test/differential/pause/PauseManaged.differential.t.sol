// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { IPauseManaged } from "@tsxo/libsol/pause/managed/IPauseManaged.sol";

import { PauseManagedHarness } from "test/harness/pause/PauseManagedHarness.sol";
import { PauseManagedReferenceHarness } from "test/harness/pause/PauseManagedReferenceHarness.sol";

import { AuthorityReplies } from "../AuthorityReplies.sol";

/// @notice The assembly `PauseManaged` matches the Solidity reference for any
/// sequence of guarded calls and pause authority changes, whatever the
/// authority replies.
contract PauseManagedDifferentialTest is AuthorityReplies {
    enum Action {
        Increment,
        Decrement,
        CountWhenNotPaused,
        SetPauseAuthority
    }

    /// @dev One fuzzed step. `newAuthority` picks from `authorities`.
    struct Step {
        uint8 action;
        bool byAuthority;
        uint8 newAuthority;
    }

    PauseManagedHarness actual;
    PauseManagedReferenceHarness expected;

    function setUp() public {
        _setUpAuthorities();
        // Replies `false`: not paused.
        actual = new PauseManagedHarness(authorities[1]);
        expected = new PauseManagedReferenceHarness(authorities[1]);
    }

    function testFuzz_AnySequence_MatchesReference(Step[STEPS] calldata steps) public {
        for (uint256 i; i < STEPS; ++i) {
            Step calldata step = steps[i];
            Action action = Action(bound(step.action, 0, uint256(type(Action).max)));
            address caller = _caller(step.byAuthority, expected.pauseAuthority());

            bytes memory data;
            if (action == Action.Increment) {
                data = abi.encodeCall(PauseManagedHarness.increment, ());
            } else if (action == Action.Decrement) {
                data = abi.encodeCall(PauseManagedHarness.decrement, ());
            } else if (action == Action.CountWhenNotPaused) {
                data = abi.encodeCall(PauseManagedHarness.countWhenNotPaused, ());
            } else {
                data = abi.encodeCall(IPauseManaged.setPauseAuthority, (_authority(step.newAuthority)));
            }

            _callBoth(address(actual), address(expected), caller, data);

            assertEq(actual.pauseAuthority(), expected.pauseAuthority(), "authority");
            assertEq(actual.count(), expected.count(), "count");
        }
    }
}
