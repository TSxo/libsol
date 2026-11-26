// SPDX-License-Identifier: MIT
pragma solidity 0.8.39;

import { stdError } from "forge-std/StdError.sol";
import { Test } from "forge-std/Test.sol";

import { CallContext } from "@tsxo/libsol/proxy/CallContext.sol";
import { ERC1967 } from "@tsxo/libsol/proxy/ERC1967/ERC1967.sol";
import { Initializable } from "@tsxo/libsol/proxy/Initializable.sol";
import { UUPSProxy } from "@tsxo/libsol/proxy/UUPS/UUPSProxy.sol";
import { BeaconProxy } from "@tsxo/libsol/proxy/beacon/BeaconProxy.sol";
import { UpgradeableBeacon } from "@tsxo/libsol/proxy/beacon/UpgradeableBeacon.sol";

import { UUPSCounter, UUPSCounterV2, Unauthorized } from "test/harness/proxy/UUPSCounter.sol";
import { NonCompliantContract, WrongImplementationSlotContract } from "test/mocks/NonCompliantImplementations.sol";

interface TestEvents {
    event Upgraded(address indexed impl);
    event Count(uint256 n);
    event Received(uint256 val);
    event UpgradedV2();
}

abstract contract UUPSTestBase is Test, TestEvents {
    // =========================================================================
    // State
    // =========================================================================

    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    UUPSCounter impl;
    UUPSCounterV2 implV2;
    UUPSProxy proxy;
    UUPSCounter proxied;

    // =========================================================================
    // Set Up
    // =========================================================================

    function setUp() public {
        bytes memory initData = abi.encodeCall(UUPSCounter.initialize, (address(this)));

        impl = new UUPSCounter();
        implV2 = new UUPSCounterV2();
        proxy = new UUPSProxy(address(impl), initData);

        proxied = UUPSCounter(payable(address(proxy)));
    }
}

contract UUPSConstructorTest is UUPSTestBase {
    function test_ProxyConstructor_InitializesProxy() public view {
        assertEq(proxied.owner(), address(this));
        assertEq(proxied.count(), 0);
    }

    function test_RevertWhen_ProxyConstructor_ImplementationReportsWrongSlot() public {
        address wrongSlot = address(new WrongImplementationSlotContract());

        vm.expectRevert(ERC1967.ERC1967__UpgradeFailed.selector);
        new UUPSProxy(wrongSlot, "");
    }

    function test_RevertWhen_ProxyConstructor_ImplementationIsNotProxiable() public {
        address nonCompliant = address(new NonCompliantContract());

        vm.expectRevert(ERC1967.ERC1967__UpgradeFailed.selector);
        new UUPSProxy(nonCompliant, "");
    }

    /// @dev A failing initialisation call in the constructor bubbles its error.
    function test_RevertWhen_ProxyConstructor_InitReverts() public {
        vm.expectRevert(stdError.arithmeticError);
        new UUPSProxy(address(impl), abi.encodeCall(UUPSCounter.decrement, ()));
    }
}

contract UUPSProxyCallsTest is UUPSTestBase {
    function test_ProxyCalls_DelegateToImplementation() public {
        vm.expectEmit(address(proxy));
        emit Count(1);
        proxied.increment();
        assertEq(proxied.count(), 1);

        proxied.decrement();
        assertEq(proxied.count(), 0);

        proxied.setCount(10);
        assertEq(proxied.count(), 10);

        assertEq(impl.count(), 0, "implementation storage untouched");
    }

    function testFuzz_ProxyCalls_WriteProxyStorage(uint256 newCount) public {
        proxied.setCount(newCount);
        assertEq(impl.count(), 0);
        assertEq(proxied.count(), newCount);
    }

    function test_ProxyCalls_ForwardValue() public {
        vm.deal(address(this), 2 ether);

        vm.expectEmit(address(proxy));
        emit Received(1 ether);
        (bool success,) = address(proxy).call{ value: 1 ether }("");
        assertTrue(success);

        vm.expectEmit(address(proxy));
        emit Received(1 ether);
        proxied.fundMe{ value: 1 ether }();

        assertEq(address(proxy).balance, 2 ether);
        assertEq(address(impl).balance, 0);
    }

    function testFuzz_Receive_KeepsEther(uint256 amount) public {
        amount = bound(amount, 1, 10 ether);
        vm.deal(address(this), amount);

        (bool success,) = address(proxy).call{ value: amount }("");
        assertTrue(success);
        assertEq(address(proxy).balance, amount);
    }
}

contract UUPSUpgradeTest is UUPSTestBase {
    function test_UpgradeToAndCall_SwitchesImplementation() public {
        proxied.setCount(5);

        vm.expectEmit(true, false, false, false, address(proxy));
        emit Upgraded(address(implV2));
        proxied.upgradeToAndCall(address(implV2), "");

        UUPSCounterV2 proxiedV2 = UUPSCounterV2(payable(address(proxy)));
        assertEq(proxiedV2.count(), 5, "storage kept");
        assertFalse(proxiedV2.upgraded());

        vm.expectEmit(address(proxy));
        emit UpgradedV2();
        proxiedV2.markAsUpgraded();
        assertTrue(proxiedV2.upgraded());
    }

    function test_UpgradeToAndCall_RunsData() public {
        proxied.setCount(5);

        vm.expectEmit(true, false, false, false, address(proxy));
        emit Upgraded(address(implV2));
        vm.expectEmit(address(proxy));
        emit UpgradedV2();
        proxied.upgradeToAndCall(address(implV2), abi.encodeCall(UUPSCounterV2.markAsUpgraded, ()));

        UUPSCounterV2 proxiedV2 = UUPSCounterV2(payable(address(proxy)));
        assertTrue(proxiedV2.upgraded());
        assertEq(proxiedV2.count(), 5);
    }

    function testFuzz_UpgradeToAndCall_PreservesState(uint256 startCount) public {
        proxied.setCount(startCount);
        bytes memory mark = abi.encodeCall(UUPSCounterV2.markAsUpgraded, ());

        proxied.upgradeToAndCall(address(implV2), mark);
        UUPSCounterV2 proxiedV2 = UUPSCounterV2(payable(address(proxy)));
        assertEq(proxiedV2.count(), startCount);
        assertTrue(proxiedV2.upgraded());

        proxiedV2.upgradeToAndCall(address(new UUPSCounterV2()), mark);
        assertEq(proxiedV2.count(), startCount);
        assertTrue(proxiedV2.upgraded());
    }

    /// @dev Documented behaviour: ETH sent with empty `data` stays in the proxy.
    function test_UpgradeToAndCall_EmptyDataKeepsEther() public {
        vm.deal(address(this), 1 ether);

        proxied.upgradeToAndCall{ value: 1 ether }(address(implV2), "");

        assertEq(address(proxy).balance, 1 ether);
        assertEq(address(uint160(uint256(vm.load(address(proxy), IMPLEMENTATION_SLOT)))), address(implV2));
    }

    function test_RevertWhen_UpgradeToAndCall_ImplementationIsNotProxiable() public {
        address nonCompliant = address(new NonCompliantContract());

        vm.expectRevert(ERC1967.ERC1967__UpgradeFailed.selector);
        proxied.upgradeToAndCall(nonCompliant, "");
    }

    function test_RevertWhen_UpgradeToAndCall_ImplementationReportsWrongSlot() public {
        address wrongSlot = address(new WrongImplementationSlotContract());

        vm.expectRevert(ERC1967.ERC1967__UpgradeFailed.selector);
        proxied.upgradeToAndCall(wrongSlot, "");
    }

    function test_RevertWhen_UpgradeToAndCall_CallerIsNotOwner() public {
        vm.expectRevert(Unauthorized.selector);
        vm.prank(makeAddr("attacker"));
        proxied.upgradeToAndCall(address(implV2), "");
    }
}

contract UUPSCallContextTest is UUPSTestBase {
    function test_ProxiableUUID_DirectCallSucceeds() public view {
        assertEq(impl.proxiableUUID(), IMPLEMENTATION_SLOT);
    }

    /// @dev Stops an upgrade to another proxy, which could not upgrade itself.
    function test_RevertWhen_ProxiableUUID_CalledThroughProxy() public {
        vm.expectRevert(CallContext.CallContext__Unauthorized.selector);
        proxied.proxiableUUID();
    }

    function test_RevertWhen_UpgradeToAndCall_CalledOnImplementation() public {
        vm.expectRevert(CallContext.CallContext__Unauthorized.selector);
        impl.upgradeToAndCall(address(implV2), "");
    }

    /// @dev A beacon proxy never reads its own ERC-1967 implementation slot,
    /// so an upgrade through it would succeed and change nothing.
    function test_RevertWhen_UpgradeToAndCall_CalledThroughBeaconProxy() public {
        UpgradeableBeacon beacon = new UpgradeableBeacon(address(this), address(impl));
        bytes memory initData = abi.encodeCall(UUPSCounter.initialize, (address(this)));
        UUPSCounter beaconProxied = UUPSCounter(payable(address(new BeaconProxy(address(beacon), initData))));

        vm.expectRevert(CallContext.CallContext__Unauthorized.selector);
        beaconProxied.upgradeToAndCall(address(implV2), "");
    }

    /// @dev Any delegatecaller whose implementation slot does not hold this
    /// implementation is rejected, not only a beacon proxy. Here the caller is
    /// this test contract, whose slot is empty.
    function test_RevertWhen_UpgradeToAndCall_DelegatecallerSlotIsNotSelf() public {
        (bool success, bytes memory result) =
            address(impl).delegatecall(abi.encodeCall(impl.upgradeToAndCall, (address(implV2), "")));

        assertFalse(success);
        assertEq(result, abi.encodeWithSelector(CallContext.CallContext__Unauthorized.selector));
    }
}

contract UUPSInitializationTest is UUPSTestBase {
    /// @dev The implementation locks itself, so nobody can take it over by
    /// initializing it directly.
    function test_RevertWhen_Initialize_CalledOnImplementation() public {
        vm.expectRevert(Initializable.Initializable__InvalidInitialization.selector);
        impl.initialize(makeAddr("attacker"));
    }

    /// @dev The proxy was initialized at deployment and cannot be again.
    function test_RevertWhen_Initialize_ProxyIsInitialized() public {
        vm.expectRevert(Initializable.Initializable__InvalidInitialization.selector);
        proxied.initialize(makeAddr("attacker"));
    }
}
