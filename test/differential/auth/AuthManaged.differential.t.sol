// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { IAuthManaged } from "@tsxo/libsol/auth/managed/IAuthManaged.sol";

import { AuthManagedHarness } from "test/harness/auth/AuthManagedHarness.sol";
import { AuthManagedReferenceHarness } from "test/harness/auth/AuthManagedReferenceHarness.sol";

import { AuthorityReplies } from "../AuthorityReplies.sol";

/// @notice The assembly `AuthManaged` matches the Solidity reference for any
/// sequence of guarded calls and authority changes, whatever the authority
/// replies.
contract AuthManagedDifferentialTest is AuthorityReplies {
    enum Action {
        Increment,
        Decrement,
        SetAuthority
    }

    /// @dev One fuzzed step. `newAuthority` picks from `authorities`.
    struct Step {
        uint8 action;
        bool byAuthority;
        uint8 newAuthority;
    }

    AuthManagedHarness actual;
    AuthManagedReferenceHarness expected;

    function setUp() public {
        _setUpAuthorities();
        actual = new AuthManagedHarness(authorities[0]);
        expected = new AuthManagedReferenceHarness(authorities[0]);
    }

    function testFuzz_AnySequence_MatchesReference(Step[STEPS] calldata steps) public {
        for (uint256 i; i < STEPS; ++i) {
            Step calldata step = steps[i];
            Action action = Action(bound(step.action, 0, uint256(type(Action).max)));
            address caller = _caller(step.byAuthority, expected.authority());

            bytes memory data;
            if (action == Action.Increment) {
                data = abi.encodeCall(AuthManagedHarness.increment, ());
            } else if (action == Action.Decrement) {
                data = abi.encodeCall(AuthManagedHarness.decrement, ());
            } else {
                data = abi.encodeCall(IAuthManaged.setAuthority, (_authority(step.newAuthority)));
            }

            _callBoth(address(actual), address(expected), caller, data);

            assertEq(actual.authority(), expected.authority(), "authority");
            assertEq(actual.count(), expected.count(), "count");
        }
    }
}
