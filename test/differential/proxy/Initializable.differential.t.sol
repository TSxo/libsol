// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { InitializableHarness } from "test/harness/proxy/InitializableHarness.sol";
import { InitializableReferenceHarness } from "test/harness/proxy/InitializableReferenceHarness.sol";

import { DifferentialBase } from "../DifferentialBase.sol";

/// @notice The assembly `Initializable` behaves exactly like the Solidity
/// reference for any sequence of initializer calls.
contract InitializableDifferentialTest is DifferentialBase {
    enum Action {
        Initialize,
        Reinitialize,
        InitializeParentDirectly,
        DisableInitializers,
        DisableWhileInitializing
    }

    /// @dev One fuzzed step. `version` is bounded to a small range, so that
    /// repeats, lower versions, and zero all occur.
    struct Step {
        uint8 action;
        uint8 version;
        uint256 value;
    }

    InitializableHarness actual;
    InitializableReferenceHarness expected;

    function setUp() public {
        actual = new InitializableHarness();
        expected = new InitializableReferenceHarness();
    }

    function testFuzz_AnySequence_MatchesReference(Step[STEPS] calldata steps) public {
        for (uint256 i; i < STEPS; ++i) {
            _callBoth(address(actual), address(expected), address(this), _operation(steps[i]));

            assertEq(actual.exposed_initializedVersion(), expected.exposed_initializedVersion(), "version");
            assertEq(actual.exposed_isInitializing(), expected.exposed_isInitializing(), "initializing");
            assertEq(actual.value(), expected.value(), "value");
            assertEq(actual.parentCalls(), expected.parentCalls(), "parent calls");
        }
    }

    function _operation(Step calldata step) internal pure returns (bytes memory) {
        Action action = Action(bound(step.action, 0, uint256(type(Action).max)));
        uint64 version = uint64(bound(step.version, 0, 7));

        if (action == Action.Initialize) {
            return abi.encodeCall(InitializableHarness.initialize, (step.value));
        }

        if (action == Action.Reinitialize) {
            return abi.encodeCall(InitializableHarness.reinitialize, (version, step.value));
        }

        if (action == Action.InitializeParentDirectly) {
            return abi.encodeCall(InitializableHarness.exposed_initializeParentDirectly, ());
        }

        if (action == Action.DisableInitializers) {
            return abi.encodeCall(InitializableHarness.exposed_disableInitializers, ());
        }

        return abi.encodeCall(InitializableHarness.disableWhileInitializing, ());
    }
}
