// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { stdError } from "forge-std/StdError.sol";
import { Test } from "forge-std/Test.sol";

import { ERC1967 } from "@tsxo/libsol/proxy/ERC1967/ERC1967.sol";

import { ERC1967Harness } from "test/harness/proxy/ERC1967Harness.sol";
import { BeaconMock, RevertingBeaconMock } from "test/mocks/BeaconMock.sol";
import { CounterTarget } from "test/mocks/CounterTarget.sol";

interface TestEvents {
    event Upgraded(address indexed implementation);
    event AdminChanged(address previousAdmin, address newAdmin);
    event BeaconUpgraded(address indexed beacon);
    event Count(uint256 n);
}

abstract contract ERC1967TestBase is Test, TestEvents {
    ERC1967Harness proxy;
    CounterTarget counter;

    function setUp() public {
        proxy = new ERC1967Harness();
        counter = new CounterTarget();
    }
}

contract ERC1967ImplementationTest is ERC1967TestBase {
    function test_UpgradeToAndCall_SetsImplementationAndEmits() public {
        vm.expectEmit(true, false, false, false, address(proxy));
        emit Upgraded(address(counter));
        proxy.exposed_upgradeToAndCall(address(counter), "");

        assertEq(proxy.exposed_implementation(), address(counter));
    }

    function test_UpgradeToAndCall_RunsData() public {
        vm.expectEmit(address(proxy));
        emit Count(7);
        proxy.exposed_upgradeToAndCall(address(counter), abi.encodeCall(CounterTarget.setCount, (7)));
    }

    function test_RevertWhen_UpgradeToAndCall_DataReverts() public {
        vm.expectRevert(stdError.arithmeticError);
        proxy.exposed_upgradeToAndCall(address(counter), abi.encodeCall(CounterTarget.decrement, ()));
    }

    function testFuzz_RevertWhen_UpgradeToAndCall_ImplementationHasNoCode(address account) public {
        vm.assume(account.code.length == 0);

        vm.expectRevert(ERC1967.ERC1967__UpgradeFailed.selector);
        proxy.exposed_upgradeToAndCall(account, "");
    }
}

contract ERC1967AdminTest is ERC1967TestBase {
    function testFuzz_ChangeAdmin_SetsAdminAndEmits(address first, address second) public {
        vm.assume(first != address(0) && second != address(0));

        vm.expectEmit(address(proxy));
        emit AdminChanged(address(0), first);
        proxy.exposed_changeAdmin(first);

        vm.expectEmit(address(proxy));
        emit AdminChanged(first, second);
        proxy.exposed_changeAdmin(second);

        assertEq(proxy.exposed_admin(), second);
    }

    function test_RevertWhen_ChangeAdmin_AdminIsZeroAddress() public {
        vm.expectRevert(ERC1967.ERC1967__InvalidAdmin.selector);
        proxy.exposed_changeAdmin(address(0));
    }

    /// @dev The admin slot is shared by convention, so another contract may
    /// have left junk above the address. The event reports the clean address.
    function testFuzz_ChangeAdmin_CleansPreviousAdminInEvent(address previous, uint96 junk, address newAdmin) public {
        vm.assume(newAdmin != address(0));

        bytes32 adminSlot = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
        vm.store(address(proxy), adminSlot, bytes32(uint256(uint160(previous)) | (uint256(junk) << 160)));

        vm.expectEmit(address(proxy));
        emit AdminChanged(previous, newAdmin);
        proxy.exposed_changeAdmin(newAdmin);
    }
}

contract ERC1967BeaconTest is ERC1967TestBase {
    function test_UpgradeBeaconToAndCall_SetsBeaconAndEmits() public {
        BeaconMock beacon = new BeaconMock(address(counter));

        vm.expectEmit(true, false, false, false, address(proxy));
        emit BeaconUpgraded(address(beacon));
        proxy.exposed_upgradeBeaconToAndCall(address(beacon), "");

        assertEq(proxy.exposed_beacon(), address(beacon));
        assertEq(proxy.exposed_implementation(), address(0), "implementation slot untouched");
    }

    function test_UpgradeBeaconToAndCall_RunsDataOnBeaconImplementation() public {
        BeaconMock beacon = new BeaconMock(address(counter));

        vm.expectEmit(address(proxy));
        emit Count(9);
        proxy.exposed_upgradeBeaconToAndCall(address(beacon), abi.encodeCall(CounterTarget.setCount, (9)));
    }

    function test_RevertWhen_UpgradeBeaconToAndCall_DataReverts() public {
        BeaconMock beacon = new BeaconMock(address(counter));

        vm.expectRevert(stdError.arithmeticError);
        proxy.exposed_upgradeBeaconToAndCall(address(beacon), abi.encodeCall(CounterTarget.decrement, ()));
    }

    function testFuzz_RevertWhen_UpgradeBeaconToAndCall_BeaconHasNoCode(address account) public {
        vm.assume(account.code.length == 0);

        vm.expectRevert(ERC1967.ERC1967__InvalidBeacon.selector);
        proxy.exposed_upgradeBeaconToAndCall(account, "");
    }

    function testFuzz_RevertWhen_UpgradeBeaconToAndCall_ImplementationHasNoCode(address account) public {
        vm.assume(account.code.length == 0);
        BeaconMock beacon = new BeaconMock(account);

        vm.expectRevert(ERC1967.ERC1967__InvalidBeacon.selector);
        proxy.exposed_upgradeBeaconToAndCall(address(beacon), "");
    }

    function test_RevertWhen_UpgradeBeaconToAndCall_BeaconReverts() public {
        RevertingBeaconMock beacon = new RevertingBeaconMock();

        vm.expectRevert(ERC1967.ERC1967__InvalidBeacon.selector);
        proxy.exposed_upgradeBeaconToAndCall(address(beacon), "");
    }

    /// @dev A word with dirty high bits must still reach the implementation in
    /// its low 160 bits. The EVM's address opcodes ignore the high bits, so this
    /// passes with or without the mask; the mask is there for Solidity's rule
    /// that `address` variables are clean.
    function test_UpgradeBeaconToAndCall_IgnoresDirtyHighBits() public {
        BeaconMock beacon = new BeaconMock(address(counter));
        bytes32 dirty = bytes32(uint256(uint160(address(counter))) | (uint256(0xff) << 200));
        vm.mockCall(address(beacon), abi.encodeWithSignature("implementation()"), abi.encode(dirty));

        vm.expectEmit(address(proxy));
        emit Count(3);
        proxy.exposed_upgradeBeaconToAndCall(address(beacon), abi.encodeCall(CounterTarget.setCount, (3)));
    }
}
