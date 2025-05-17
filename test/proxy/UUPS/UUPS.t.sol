// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { UUPSProxy } from "@tsxo/libsol/proxy/UUPS/UUPSProxy.sol";
import { ERC1967Logic } from "@tsxo/libsol/proxy/ERC1967/ERC1967Logic.sol";
import { UUPSCounterMock, UUPSCounterV2Mock } from "@tsxo/libsol/mocks/proxy/UUPS/UUPSImplementationMock.sol";
import {
    NonCompliantContract,
    WrongImplementationSlotContract
} from "@tsxo/libsol/mocks/proxy/UUPS/UUPSNonCompliantMock.sol";

interface TestEvents {
    event Upgraded(address indexed impl);
    event Count(uint256 n);
    event Received(uint256 val);
    event UpgradedV2();
}

contract UUPSTest is Test, TestEvents {
    // -------------------------------------------------------------------------
    // State

    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    UUPSCounterMock impl;
    UUPSCounterV2Mock implV2;
    UUPSProxy proxy;
    UUPSCounterMock proxied;

    // -------------------------------------------------------------------------
    // Set Up

    function setUp() public {
        bytes memory initData = abi.encodeWithSignature("initialize()");

        impl = new UUPSCounterMock();
        implV2 = new UUPSCounterV2Mock();
        proxy = new UUPSProxy(address(impl), initData);

        proxied = UUPSCounterMock(payable(address(proxy)));
    }

    // -------------------------------------------------------------------------
    // Test - Proxy Construction

    function test_ProxyConstructor_RejectsNonERC1822CompliantContracts() public {
        bytes4 err = ERC1967Logic.ERC1967Logic__UpgradeFailed.selector;

        address wrongSlot = address(new WrongImplementationSlotContract());
        address nonCompliant = address(new NonCompliantContract());

        vm.expectRevert(err);
        new UUPSProxy(wrongSlot, "");

        vm.expectRevert();
        new UUPSProxy(nonCompliant, "");
    }

    // -------------------------------------------------------------------------
    // Test - Proxy Initialization

    function test_ProxyInitialization() public view {
        bytes memory countCall = abi.encodeWithSignature("count()");
        (bool success, bytes memory data) = address(proxy).staticcall(countCall);
        uint256 count = abi.decode(data, (uint256));

        assertTrue(success);
        assertEq(count, 0);
    }

    // -------------------------------------------------------------------------
    // Basic Functionality Tests

    function test_ProxyCalls_DelegateToImplementation() public {
        proxied.increment();
        assertEq(proxied.count(), 1);

        proxied.decrement();
        assertEq(proxied.count(), 0);

        proxied.setCount(10);
        assertEq(proxied.count(), 10);

        assertEq(impl.count(), 0);
    }

    function test_ProxyCalls_HandlesLowLevelCalls() public {
        bytes memory countCall = abi.encodeWithSignature("count()");
        bytes memory incCall = abi.encodeWithSignature("increment()");
        bytes memory decCall = abi.encodeWithSignature("decrement()");
        bytes memory setCall = abi.encodeWithSignature("setCount(uint256)", 10);
        bytes memory notExist = abi.encodeWithSignature("notExist()");

        (bool success, bytes memory data) = address(proxy).staticcall(countCall);
        uint256 count = abi.decode(data, (uint256));
        assertTrue(success);
        assertEq(count, 0);

        vm.expectEmit(false, false, false, true, address(proxy));
        emit Count(1);
        (success, data) = address(proxy).call(incCall);
        assertTrue(success);

        (success, data) = address(proxy).staticcall(countCall);
        count = abi.decode(data, (uint256));
        assertTrue(success);
        assertEq(count, 1);

        vm.expectEmit(false, false, false, true, address(proxy));
        emit Count(0);
        (success, data) = address(proxy).call(decCall);
        assertTrue(success);

        (success, data) = address(proxy).staticcall(countCall);
        count = abi.decode(data, (uint256));
        assertTrue(success);
        assertEq(count, 0);

        vm.expectEmit(false, false, false, true, address(proxy));
        emit Count(10);
        (success, data) = address(proxy).call(setCall);
        assertTrue(success);

        (success, data) = address(proxy).staticcall(countCall);
        count = abi.decode(data, (uint256));
        assertTrue(success);
        assertEq(count, 10);

        (success, data) = address(proxy).call(notExist);
        assertFalse(success);
    }

    // -------------------------------------------------------------------------
    // Test - Ether Handling

    function test_ProxyEtherHandling() public {
        bytes memory fundCall = abi.encodeWithSignature("fundMe()");
        address user = address(0x1234);

        vm.startPrank(user);
        vm.deal(user, 2 ether);

        assertEq(address(proxy).balance, 0);
        assertEq(address(impl).balance, 0);

        vm.expectEmit(false, false, false, true, address(proxy));
        emit Received(1 ether);

        (bool success,) = address(proxy).call{ value: 1 ether }("");
        assertTrue(success);
        assertEq(address(proxy).balance, 1 ether);
        assertEq(address(impl).balance, 0);

        vm.expectEmit(false, false, false, true, address(proxy));
        emit Received(1 ether);

        (success,) = address(proxy).call{ value: 1 ether }(fundCall);
        assertTrue(success);
        assertEq(address(proxy).balance, 2 ether);
        assertEq(address(impl).balance, 0);

        vm.stopPrank();
    }

    // -------------------------------------------------------------------------
    // Test - Upgrade

    function test_Upgrade() public {
        proxied.setCount(5);
        assertEq(proxied.count(), 5);

        bytes memory upgradeCall = abi.encodeWithSignature("upgradeToAndCall(address,bytes)", address(implV2), "");

        vm.expectEmit(true, false, false, false, address(proxy));
        emit Upgraded(address(implV2));

        (bool success,) = address(proxy).call(upgradeCall);
        assertTrue(success);

        UUPSCounterV2Mock proxiedV2 = UUPSCounterV2Mock(payable(address(proxy)));

        assertEq(proxiedV2.count(), 5);

        assertEq(proxiedV2.upgraded(), false);

        vm.expectEmit(false, false, false, false, address(proxy));
        emit UpgradedV2();

        proxiedV2.markAsUpgraded();
        assertTrue(proxiedV2.upgraded());
    }

    function test_UpgradeWithCall() public {
        proxied.setCount(5);
        assertEq(proxied.count(), 5);

        bytes memory initCall = abi.encodeWithSignature("markAsUpgraded()");
        bytes memory upgradeCall = abi.encodeWithSignature("upgradeToAndCall(address,bytes)", address(implV2), initCall);

        vm.expectEmit(true, false, false, false, address(proxy));
        emit Upgraded(address(implV2));

        vm.expectEmit(false, false, false, false, address(proxy));
        emit UpgradedV2();

        (bool success,) = address(proxy).call(upgradeCall);
        assertTrue(success);

        UUPSCounterV2Mock proxiedV2 = UUPSCounterV2Mock(payable(address(proxy)));

        assertTrue(proxiedV2.upgraded());
        assertEq(proxiedV2.count(), 5);
    }

    function test_FailedUpgrade_NotERC1822Compliant() public {
        address nonCompliant = address(new NonCompliantContract());

        bytes memory upgradeCall = abi.encodeWithSignature("upgradeToAndCall(address,bytes)", nonCompliant, "");

        (bool success,) = address(proxy).call(upgradeCall);
        assertFalse(success);
    }

    function test_FailedUpgrade_WrongImplementationSlot() public {
        address wrongSlot = address(new WrongImplementationSlotContract());

        bytes memory upgradeCall = abi.encodeWithSignature("upgradeToAndCall(address,bytes)", wrongSlot, "");

        (bool success,) = address(proxy).call(upgradeCall);
        assertFalse(success);
    }

    function test_FailedUpgrade_Unauthorized() public {
        address attacker = address(0x5678);
        vm.startPrank(attacker);

        bytes memory upgradeCall = abi.encodeWithSignature("upgradeToAndCall(address,bytes)", address(implV2), "");

        (bool success,) = address(proxy).call(upgradeCall);
        assertFalse(success);

        vm.stopPrank();
    }

    // -------------------------------------------------------------------------
    // Test - Call Context

    function test_ProxiableUUID_DirectCallSucceeds() public view {
        bytes32 actualSlot = impl.proxiableUUID();
        assertEq(actualSlot, IMPLEMENTATION_SLOT);
    }

    function test_ProxiableUUID_ProxiedCallReverts() public view {
        bytes memory proxiableUUIDCall = abi.encodeWithSignature("proxiableUUID()");

        (bool success,) = address(proxy).staticcall(proxiableUUIDCall);
        assertFalse(success);
    }

    function test_UpgradeToAndCall_DirectCallReverts() public {
        address tempImpl = address(new UUPSCounterV2Mock());

        vm.expectRevert();
        impl.upgradeToAndCall(tempImpl, "");
    }

    // -------------------------------------------------------------------------
    // Fuzz Tests

    function testFuzz_SetCount(uint256 newCount) public {
        proxied.setCount(newCount);
        assertEq(impl.count(), 0);
        assertEq(proxied.count(), newCount);
    }

    function testFuzz_MultipleUpgradesPreserveState(uint256 startCount) public {
        proxied.setCount(startCount);
        assertEq(proxied.count(), startCount);

        bytes memory initCall = abi.encodeWithSignature("markAsUpgraded()");
        bytes memory upgradeCall = abi.encodeWithSignature("upgradeToAndCall(address,bytes)", address(implV2), initCall);

        (bool success,) = address(proxy).call(upgradeCall);
        assertTrue(success);

        UUPSCounterV2Mock proxiedV2 = UUPSCounterV2Mock(payable(address(proxy)));
        assertEq(proxiedV2.count(), startCount);
        assertTrue(proxiedV2.upgraded());

        UUPSCounterV2Mock implV3 = new UUPSCounterV2Mock();

        upgradeCall = abi.encodeWithSignature("upgradeToAndCall(address,bytes)", address(implV3), initCall);
        (success,) = address(proxy).call(upgradeCall);
        assertTrue(success);

        UUPSCounterV2Mock proxiedV3 = UUPSCounterV2Mock(payable(address(proxy)));
        assertEq(proxiedV3.count(), startCount);
        assertTrue(proxiedV3.upgraded());
    }

    function testFuzz_EtherHandling(uint256 amount) public {
        vm.assume(amount > 0 && amount < 10 ether);

        (bool success,) = address(proxy).call{ value: amount }("");
        assertTrue(success);
        assertEq(address(proxy).balance, amount);
    }

    // -------------------------------------------------------------------------
    // Invariant Tests

    function invariant_ImplementationSlotMatchesProxiableUUID() public view {
        bytes32 actualSlot = impl.proxiableUUID();
        assertEq(actualSlot, IMPLEMENTATION_SLOT);
    }
}
