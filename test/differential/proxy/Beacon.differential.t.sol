// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Vm } from "forge-std/Test.sol";

import { IOwned } from "@tsxo/libsol/auth/IOwned.sol";
import { BeaconProxy } from "@tsxo/libsol/proxy/beacon/BeaconProxy.sol";
import { IBeacon } from "@tsxo/libsol/proxy/beacon/IBeacon.sol";
import { IUpgradeableBeacon } from "@tsxo/libsol/proxy/beacon/IUpgradeableBeacon.sol";
import { UpgradeableBeacon } from "@tsxo/libsol/proxy/beacon/UpgradeableBeacon.sol";

import { UpgradeableBeaconHarness } from "test/harness/proxy/UpgradeableBeaconHarness.sol";
import { CounterTarget } from "test/mocks/CounterTarget.sol";
import { ScriptedMock } from "test/mocks/ScriptedMock.sol";
import { BeaconProxyReference, UpgradeableBeaconReference } from "test/reference/proxy/BeaconReference.sol";

import { DifferentialBase } from "../DifferentialBase.sol";

/// @notice The assembly `UpgradeableBeacon` and `BeaconProxy` match the
/// Solidity references: the beacon for any sequence of upgrades and ownership
/// changes; the proxy from construction onwards, for any beacon, including one
/// whose reply goes bad between calls.
contract BeaconDifferentialTest is DifferentialBase {
    address owner = makeAddr("owner");
    address user = makeAddr("user");
    address eoa = makeAddr("eoa");

    address counter;
    address otherCounter;

    UpgradeableBeacon beacon;

    /// @dev Addresses to upgrade to, or to transfer ownership to.
    address[] accounts;

    /// @dev Beacons to build proxies on, good and bad.
    address[] beacons;

    /// @dev Replies a beacon can switch to after construction.
    bytes[] replies;

    function setUp() public {
        counter = address(new CounterTarget());
        otherCounter = address(new CounterTarget());
        beacon = new UpgradeableBeacon(owner, counter);

        // Implementations with code, an account without code, zero, and the
        // two actors, who can also receive ownership.
        accounts.push(counter);
        accounts.push(otherCounter);
        accounts.push(eoa);
        accounts.push(address(0));
        accounts.push(owner);
        accounts.push(user);

        // The real beacon, then mocks replying to `implementation()` with:
        beacons.push(address(beacon));
        beacons.push(_mock(false, abi.encode(counter))); // a clean address
        beacons.push(_mock(false, abi.encode(_dirtyAddressWord(counter)))); // junk above the address
        beacons.push(_mock(false, abi.encode(counter, uint256(0)))); // two words
        beacons.push(_mock(false, abi.encode(eoa))); // an account without code
        beacons.push(_mock(false, hex"0011")); // two bytes
        beacons.push(_mock(true, abi.encodeWithSignature("Error(string)", "no beacon"))); // a revert
        beacons.push(eoa); // and a beacon without code

        // What a beacon can switch to replying after construction: another
        // implementation, two words, two bytes, nothing.
        replies.push(abi.encode(otherCounter));
        replies.push(abi.encode(counter, uint256(0)));
        replies.push(hex"0011");
        replies.push("");
    }

    // =========================================================================
    // UpgradeableBeacon
    // =========================================================================

    enum BeaconAction {
        UpgradeTo,
        TransferOwnership
    }

    /// @dev One fuzzed beacon step. `account` picks from `accounts`.
    struct BeaconStep {
        uint8 action;
        bool byOwner;
        uint8 account;
    }

    function testFuzz_Beacon_MatchesReference(BeaconStep[STEPS] calldata steps) public {
        UpgradeableBeacon actual = new UpgradeableBeaconHarness(owner, counter);
        UpgradeableBeaconReference expected = new UpgradeableBeaconReference(owner, counter);

        for (uint256 i; i < STEPS; ++i) {
            BeaconStep calldata step = steps[i];
            BeaconAction action = BeaconAction(bound(step.action, 0, uint256(type(BeaconAction).max)));
            address caller = step.byOwner ? expected.owner() : user;
            address account = accounts[bound(step.account, 0, accounts.length - 1)];

            bytes memory data = action == BeaconAction.UpgradeTo
                ? abi.encodeCall(IUpgradeableBeacon.upgradeTo, (account))
                : abi.encodeCall(IOwned.transferOwnership, (account));

            _callBoth(address(actual), address(expected), caller, data);

            assertEq(actual.implementation(), expected.implementation(), "implementation");
            assertEq(actual.owner(), expected.owner(), "owner");
        }
    }

    // =========================================================================
    // BeaconProxy
    // =========================================================================

    enum ProxyAction {
        CallProxy,
        UpgradeBeacon,
        ChangeBeaconReply
    }

    /// @dev One fuzzed proxy step. For `CallProxy`, `call` and `value` build
    /// the calldata (`_counterCall`). For `UpgradeBeacon`, `pick` chooses from
    /// `accounts`. For `ChangeBeaconReply`, `pick` chooses one of `replies`, a
    /// revert, or a return to the beacon's real reply.
    struct ProxyStep {
        uint8 action;
        uint8 call;
        uint256 value;
        uint8 pick;
    }

    /// @dev Builds both proxies on the same beacon, chosen from `beacons`, with
    /// the same initialisation call, then runs the steps against both.
    function testFuzz_Proxy_MatchesReference(
        uint8 beaconPick,
        uint8 initCall,
        uint256 initValue,
        ProxyStep[STEPS] calldata steps
    ) public {
        address chosen = beacons[bound(beaconPick, 0, beacons.length - 1)];
        (address actual, address expected) = _deployBoth(chosen, _counterCall(initCall, initValue));
        if (actual == address(0)) return;

        bytes memory query = abi.encodeCall(IBeacon.implementation, ());

        for (uint256 i; i < STEPS; ++i) {
            ProxyStep calldata step = steps[i];
            ProxyAction action = ProxyAction(bound(step.action, 0, uint256(type(ProxyAction).max)));

            if (action == ProxyAction.CallProxy) {
                _callBoth(actual, expected, address(this), _counterCall(step.call, step.value));
                assertEq(vm.load(actual, 0), vm.load(expected, 0), "count");
            } else if (action == ProxyAction.UpgradeBeacon) {
                // Upgrades the real beacon, which both proxies may read; a
                // rejected upgrade changes nothing, so the outcome is not
                // compared here but through the proxies' next calls.
                vm.prank(owner);
                (bool upgraded,) = address(beacon)
                    .call(
                        abi.encodeCall(
                            IUpgradeableBeacon.upgradeTo, (accounts[bound(step.pick, 0, accounts.length - 1)])
                        )
                    );
                upgraded;
            } else {
                uint256 pick = bound(step.pick, 0, replies.length + 1);
                if (pick < replies.length) vm.mockCall(chosen, query, replies[pick]);
                else if (pick == replies.length) vm.mockCallRevert(chosen, query, "beacon down");
                else vm.clearMockedCalls();
            }
        }
    }

    /// @dev Deploys both proxies on `chosen` and requires the same outcome: the
    /// same success, revert data, and logs.
    ///
    /// @return actual   The `BeaconProxy`, or zero if construction reverted.
    /// @return expected The reference, or zero if construction reverted.
    function _deployBoth(address chosen, bytes memory data) internal returns (address actual, address expected) {
        bytes memory args = abi.encode(chosen, data);

        vm.recordLogs();
        (actual, data) = _create(abi.encodePacked(type(BeaconProxy).creationCode, args));
        Vm.Log[] memory actualLogs = vm.getRecordedLogs();
        bytes memory actualRevert = data;

        vm.recordLogs();
        (expected, data) = _create(abi.encodePacked(type(BeaconProxyReference).creationCode, args));
        Vm.Log[] memory expectedLogs = vm.getRecordedLogs();

        assertEq(actual == address(0), expected == address(0), "construction success");
        assertEq(actualRevert, data, "construction revert data");
        _assertSameLogs(actualLogs, expectedLogs);
    }

    /// @dev Creates a contract, returning its address, or zero and the revert
    /// data.
    function _create(bytes memory initCode) internal returns (address deployed, bytes memory revertData) {
        assembly ("memory-safe") {
            deployed := create(0, add(initCode, 0x20), mload(initCode))
        }

        if (deployed == address(0)) {
            assembly ("memory-safe") {
                revertData := mload(0x40)
                mstore(revertData, returndatasize())
                returndatacopy(add(revertData, 0x20), 0x00, returndatasize())
                mstore(0x40, add(add(revertData, 0x20), returndatasize()))
            }
        }
    }

    function _mock(bool reverts, bytes memory data) internal returns (address) {
        return address(new ScriptedMock(reverts, data));
    }
}
