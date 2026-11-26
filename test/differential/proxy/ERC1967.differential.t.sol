// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { ERC1822Harness, ERC1967Harness } from "test/harness/proxy/ERC1967Harness.sol";
import { ERC1822ReferenceHarness, ERC1967ReferenceHarness } from "test/harness/proxy/ERC1967ReferenceHarness.sol";
import { CounterTarget } from "test/mocks/CounterTarget.sol";
import { ScriptedMock } from "test/mocks/ScriptedMock.sol";

import { DifferentialBase } from "../DifferentialBase.sol";

/// @notice The assembly `ERC1967` and `ERC1822` match the Solidity references
/// for any sequence of upgrades, admin changes, and beacon changes, including
/// to malformed beacons and implementations.
contract ERC1967DifferentialTest is DifferentialBase {
    enum Action {
        UpgradeToAndCall,
        ChangeAdmin,
        UpgradeBeaconToAndCall,
        UpgradeToAndCallUUPS
    }

    /// @dev One fuzzed step. `candidate` picks from `candidates`; `call` and
    /// `value` build the calldata run after an upgrade (`_counterCall`).
    struct Step {
        uint8 action;
        uint8 candidate;
        uint8 call;
        uint256 value;
    }

    bytes32 constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    ERC1967Harness actual;
    ERC1967ReferenceHarness expected;
    ERC1822Harness actualUUPS;
    ERC1822ReferenceHarness expectedUUPS;

    /// @dev Addresses to upgrade to, or to make admin or beacon.
    address[] candidates;

    function setUp() public {
        actual = new ERC1967Harness();
        expected = new ERC1967ReferenceHarness();
        actualUUPS = new ERC1822Harness();
        expectedUUPS = new ERC1822ReferenceHarness();

        address eoa = makeAddr("eoa");
        address counter = address(new CounterTarget());

        // As anything: zero, an account without code, a plain implementation.
        candidates.push(address(0));
        candidates.push(eoa);
        candidates.push(counter);

        // As implementations: ERC-1822 compliant, wrong slot, too long.
        candidates.push(_mock(false, abi.encode(IMPLEMENTATION_SLOT)));
        candidates.push(_mock(false, abi.encode(bytes32(uint256(1)))));
        candidates.push(_mock(false, abi.encode(IMPLEMENTATION_SLOT, uint256(0))));

        // As beacons: valid, dirty word, too long, too short, pointing at an
        // account without code.
        candidates.push(_mock(false, abi.encode(counter)));
        candidates.push(_mock(false, abi.encode(_dirtyAddressWord(counter))));
        candidates.push(_mock(false, abi.encode(counter, uint256(0))));
        candidates.push(_mock(false, hex"00112233445566778899aabbccddeeff00112233445566778899aabbccddee"));
        candidates.push(_mock(false, abi.encode(eoa)));

        // Reverts with data.
        candidates.push(_mock(true, abi.encodeWithSignature("Error(string)", "nope")));
    }

    function testFuzz_AnySequence_MatchesReference(Step[STEPS] calldata steps) public {
        for (uint256 i; i < STEPS; ++i) {
            Step calldata step = steps[i];
            Action action = Action(bound(step.action, 0, uint256(type(Action).max)));
            address candidate = candidates[bound(step.candidate, 0, candidates.length - 1)];
            bytes memory data = _counterCall(step.call, step.value);

            if (action == Action.UpgradeToAndCall) {
                _callBoth(
                    address(actual),
                    address(expected),
                    address(this),
                    abi.encodeCall(ERC1967Harness.exposed_upgradeToAndCall, (candidate, data))
                );
            } else if (action == Action.ChangeAdmin) {
                _callBoth(
                    address(actual),
                    address(expected),
                    address(this),
                    abi.encodeCall(ERC1967Harness.exposed_changeAdmin, (candidate))
                );
            } else if (action == Action.UpgradeBeaconToAndCall) {
                _callBoth(
                    address(actual),
                    address(expected),
                    address(this),
                    abi.encodeCall(ERC1967Harness.exposed_upgradeBeaconToAndCall, (candidate, data))
                );
            } else {
                _callBoth(
                    address(actualUUPS),
                    address(expectedUUPS),
                    address(this),
                    abi.encodeCall(ERC1822Harness.exposed_upgradeToAndCall, (candidate, data))
                );
            }

            assertEq(actual.exposed_implementation(), expected.exposed_implementation(), "implementation");
            assertEq(actual.exposed_admin(), expected.exposed_admin(), "admin");
            assertEq(actual.exposed_beacon(), expected.exposed_beacon(), "beacon");
            assertEq(actualUUPS.exposed_implementation(), expectedUUPS.exposed_implementation(), "UUPS implementation");

            // `CounterTarget.count` lands in slot 0 through the delegatecalls.
            assertEq(vm.load(address(actual), 0), vm.load(address(expected), 0), "count");
            assertEq(vm.load(address(actualUUPS), 0), vm.load(address(expectedUUPS), 0), "UUPS count");
        }
    }

    function _mock(bool reverts, bytes memory data) internal returns (address) {
        return address(new ScriptedMock(reverts, data));
    }
}
