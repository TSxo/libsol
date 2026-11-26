// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { stdError } from "forge-std/StdError.sol";
import { Test } from "forge-std/Test.sol";

import { ERC1967 } from "@tsxo/libsol/proxy/ERC1967/ERC1967.sol";
import { BeaconProxy } from "@tsxo/libsol/proxy/beacon/BeaconProxy.sol";
import { IBeacon } from "@tsxo/libsol/proxy/beacon/IBeacon.sol";
import { UpgradeableBeacon } from "@tsxo/libsol/proxy/beacon/UpgradeableBeacon.sol";

import { BeaconMock } from "test/mocks/BeaconMock.sol";
import { CounterTarget } from "test/mocks/CounterTarget.sol";

/// @notice A second implementation, to show an upgrade takes effect.
contract DoublingCounter {
    uint256 public count;

    function increment() external {
        count += 2;
    }
}

interface TestEvents {
    event BeaconUpgraded(address indexed beacon);
    event Count(uint256 n);
    event Received(uint256 val);
}

contract BeaconProxyTest is Test, TestEvents {
    bytes32 constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
    bytes32 constant BEACON_SLOT = bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1);

    address owner = makeAddr("owner");

    UpgradeableBeacon beacon;
    BeaconProxy proxy;
    CounterTarget proxied;

    function setUp() public {
        beacon = new UpgradeableBeacon(owner, address(new CounterTarget()));
        proxy = new BeaconProxy(address(beacon), "");
        proxied = CounterTarget(payable(address(proxy)));
    }

    // =========================================================================
    // Constructor
    // =========================================================================

    function test_Constructor_RecordsBeacon() public {
        vm.expectEmit(true, false, false, false);
        emit BeaconUpgraded(address(beacon));
        BeaconProxy fresh = new BeaconProxy(address(beacon), "");

        assertEq(address(uint160(uint256(vm.load(address(fresh), BEACON_SLOT)))), address(beacon));
        assertEq(vm.load(address(fresh), IMPLEMENTATION_SLOT), bytes32(0), "implementation slot untouched");
    }

    function test_Constructor_RunsData() public {
        BeaconProxy fresh = new BeaconProxy(address(beacon), abi.encodeCall(CounterTarget.setCount, (5)));
        assertEq(CounterTarget(payable(address(fresh))).count(), 5);
    }

    function test_RevertWhen_Constructor_InitReverts() public {
        vm.expectRevert(stdError.arithmeticError);
        new BeaconProxy(address(beacon), abi.encodeCall(CounterTarget.decrement, ()));
    }

    function testFuzz_RevertWhen_Constructor_BeaconHasNoCode(address account) public {
        vm.assume(account.code.length == 0);

        vm.expectRevert(ERC1967.ERC1967__InvalidBeacon.selector);
        new BeaconProxy(account, "");
    }

    function test_RevertWhen_Constructor_ImplementationHasNoCode() public {
        BeaconMock badBeacon = new BeaconMock(makeAddr("eoa"));

        vm.expectRevert(ERC1967.ERC1967__InvalidBeacon.selector);
        new BeaconProxy(address(badBeacon), "");
    }

    // =========================================================================
    // Calls
    // =========================================================================

    function test_Calls_DelegateToBeaconImplementation() public {
        vm.expectEmit(address(proxy));
        emit Count(1);
        proxied.increment();

        assertEq(proxied.count(), 1);
    }

    function test_Calls_ForwardValue() public {
        vm.deal(address(this), 1 ether);

        vm.expectEmit(address(proxy));
        emit Received(1 ether);
        proxied.fundMe{ value: 1 ether }();

        assertEq(address(proxy).balance, 1 ether);
    }

    function test_Calls_FollowBeaconUpgrade() public {
        proxied.increment();

        address doubling = address(new DoublingCounter());
        vm.prank(owner);
        beacon.upgradeTo(doubling);

        DoublingCounter(address(proxy)).increment();
        assertEq(DoublingCounter(address(proxy)).count(), 3, "storage kept, new code runs");
    }

    function test_RevertWhen_Calls_BeaconReverts() public {
        bytes memory reason = abi.encodeWithSignature("Error(string)", "beacon down");
        vm.mockCallRevert(address(beacon), abi.encodeCall(IBeacon.implementation, ()), reason);

        vm.expectRevert(reason);
        proxied.increment();
    }

    function test_RevertWhen_Calls_BeaconReplyIsMalformed() public {
        vm.mockCall(
            address(beacon), abi.encodeCall(IBeacon.implementation, ()), abi.encode(beacon.implementation(), uint256(0))
        );

        vm.expectRevert(ERC1967.ERC1967__InvalidBeacon.selector);
        proxied.increment();
    }

    function test_RevertWhen_Calls_ImplementationReverts() public {
        vm.expectRevert(stdError.arithmeticError);
        proxied.decrement();
    }
}
