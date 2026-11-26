// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";

import { IAuthManaged } from "@tsxo/libsol/auth/managed/IAuthManaged.sol";
import { IAuthority } from "@tsxo/libsol/auth/managed/IAuthority.sol";
import { IPauseAuthority } from "@tsxo/libsol/pause/managed/IPauseAuthority.sol";
import { IPauseManaged } from "@tsxo/libsol/pause/managed/IPauseManaged.sol";
import { BeaconProxy } from "@tsxo/libsol/proxy/beacon/BeaconProxy.sol";
import { IBeacon } from "@tsxo/libsol/proxy/beacon/IBeacon.sol";
import { UpgradeableBeacon } from "@tsxo/libsol/proxy/beacon/UpgradeableBeacon.sol";
import { UUPSProxy } from "@tsxo/libsol/proxy/UUPS/UUPSProxy.sol";

import { AuthManagedHarness } from "test/harness/auth/AuthManagedHarness.sol";
import { AuthManagerHarness } from "test/harness/auth/AuthManagerHarness.sol";
import { Owned2StepHarness } from "test/harness/auth/Owned2StepHarness.sol";
import { OwnedHarness } from "test/harness/auth/OwnedHarness.sol";
import { MutexHarness } from "test/harness/utils/MutexHarness.sol";
import { MutexTransientHarness } from "test/harness/utils/MutexTransientHarness.sol";
import { RateLimiterHarness } from "test/harness/utils/RateLimiterHarness.sol";
import { PausableHarness } from "test/harness/pause/PausableHarness.sol";
import { PauseManagedHarness } from "test/harness/pause/PauseManagedHarness.sol";
import { PauseManagerHarness } from "test/harness/pause/PauseManagerHarness.sol";
import { ERC1967Harness } from "test/harness/proxy/ERC1967Harness.sol";
import { InitializableHarness } from "test/harness/proxy/InitializableHarness.sol";
import { BeaconMock } from "test/mocks/BeaconMock.sol";
import { UUPSCounter } from "test/harness/proxy/UUPSCounter.sol";

/// @notice Checks the hard-coded storage slots and call selectors in `src/`.
///
/// @dev How the comparisons work:
///
/// - Storage slots: each test changes state through the contract's own
///   functions, then reads the raw slot at the location this file recomputes
///   from the ERC-7201 (or ERC-1967) formula, using `vm.load`. Transient
///   storage cannot be read that way, so its slot is read from inside a locked
///   call instead. A wrong slot constant is self-consistent (the contract reads
///   and writes the same wrong slot), so behaviour tests cannot catch it.
/// - Call selectors: each selector hard-coded in assembly is compared with the
///   one the compiler derives from the interface.
///
/// Event topics and error selectors are not checked here: the unit tests
/// already compare them with the compiler's values through `vm.expectEmit`
/// and `vm.expectRevert`.
contract ConstantsTest is Test {
    address owner = makeAddr("owner");
    address user = makeAddr("user");

    // =========================================================================
    // Helpers
    // =========================================================================

    /// @dev ERC-7201: keccak256(abi.encode(uint256(keccak256(id)) - 1)) & ~0xff.
    function _erc7201(string memory id) internal pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256(bytes(id))) - 1)) & ~bytes32(uint256(0xff));
    }

    function _addr(bytes32 word) internal pure returns (address) {
        return address(uint160(uint256(word)));
    }

    // =========================================================================
    // Storage Slots
    // =========================================================================

    function test_Slot_Owned() public {
        OwnedHarness owned = new OwnedHarness(owner);
        assertEq(_addr(vm.load(address(owned), _erc7201("libsol.storage.Owned"))), owner);
    }

    function test_Slot_Owned2Step() public {
        Owned2StepHarness owned = new Owned2StepHarness(owner);
        vm.prank(owner);
        owned.transferOwnership(user);
        assertEq(_addr(vm.load(address(owned), _erc7201("libsol.storage.Owned2Step"))), user);
    }

    function test_Slot_AuthManaged() public {
        AuthManagerHarness manager = new AuthManagerHarness(owner);
        AuthManagedHarness managed = new AuthManagedHarness(address(manager));
        assertEq(_addr(vm.load(address(managed), _erc7201("libsol.storage.AuthManaged"))), address(manager));
    }

    function test_Slot_AuthManager() public {
        AuthManagerHarness manager = new AuthManagerHarness(owner);
        bytes32 base = _erc7201("libsol.storage.AuthManager");
        address target = makeAddr("target");
        bytes4 selector = bytes4(0xd09de08a);

        vm.startPrank(owner);
        manager.setUserRole(user, 5, true);
        manager.setRoleAccess(target, selector, 7, true);
        vm.stopPrank();

        // `userRoles` is the struct's first member, `access` its second.
        bytes32 rolesSlot = keccak256(abi.encode(user, base));
        bytes32 accessSlot = keccak256(abi.encode(selector, keccak256(abi.encode(target, uint256(base) + 1))));

        assertEq(uint256(vm.load(address(manager), rolesSlot)), 1 << 5);
        assertEq(uint256(vm.load(address(manager), accessSlot)), 1 << 7);
    }

    function test_Slot_Mutex() public {
        MutexHarness mutex = new MutexHarness();
        // `_initializeMutex` stores UNLOCKED (1).
        assertEq(uint256(vm.load(address(mutex), _erc7201("libsol.storage.Mutex"))), 1);
    }

    /// @dev Transient storage cannot be read with `vm.load`, so the harness reads
    /// the computed slot from inside a locked call.
    function test_Slot_MutexTransient() public {
        MutexTransientHarness mutex = new MutexTransientHarness();
        assertEq(mutex.probeLockedSlot(_erc7201("libsol.transient.Mutex")), 1);
        assertEq(mutex.probeLockedSlot(_erc7201("libsol.storage.Mutex")), 0);
    }

    function test_Slot_RateLimiter() public {
        RateLimiterHarness limiter = new RateLimiterHarness();
        bytes32 id = keccak256("withdrawals");
        vm.warp(1000);
        limiter.exposed_setRateLimit(id, 500, 3);
        limiter.exposed_consume(id, 200);

        // Each bucket takes two slots: capacity | rate << 128, then
        // tokens | updatedAt << 128.
        bytes32 bucket = keccak256(abi.encode(id, _erc7201("libsol.storage.RateLimiter")));
        assertEq(uint256(vm.load(address(limiter), bucket)), 500 | (3 << 128));
        assertEq(uint256(vm.load(address(limiter), bytes32(uint256(bucket) + 1))), 300 | (1000 << 128));
    }

    function test_Slot_Pausable() public {
        PausableHarness pausable = new PausableHarness();
        pausable.exposed_setPaused(true);
        assertEq(uint256(vm.load(address(pausable), _erc7201("libsol.storage.Pausable"))), 1);
    }

    function test_Slot_PauseManaged() public {
        PauseManagerHarness manager = new PauseManagerHarness(owner);
        PauseManagedHarness managed = new PauseManagedHarness(address(manager));
        assertEq(_addr(vm.load(address(managed), _erc7201("libsol.storage.PauseManaged"))), address(manager));
    }

    function test_Slot_PauseManager() public {
        PauseManagerHarness manager = new PauseManagerHarness(owner);
        bytes32 base = _erc7201("libsol.storage.PauseManager");
        address target = makeAddr("target");

        vm.startPrank(owner);
        manager.setGloballyPaused(true);
        manager.setTargetPaused(target, true);
        vm.stopPrank();

        // `globallyPaused` is the struct's first member, `paused` its second.
        assertEq(uint256(vm.load(address(manager), base)), 1);
        assertEq(uint256(vm.load(address(manager), keccak256(abi.encode(target, uint256(base) + 1)))), 1);
    }

    function test_Slot_Initializable() public {
        InitializableHarness initializable = new InitializableHarness();
        initializable.initialize(42);
        // Version 1 in bits 0-63; the `initializing` bit (64) is clear again.
        assertEq(uint256(vm.load(address(initializable), _erc7201("libsol.storage.Initializable"))), 1);
    }

    function test_Slot_ERC1967Implementation() public {
        UUPSCounter impl = new UUPSCounter();
        UUPSProxy proxy = new UUPSProxy(address(impl), "");
        bytes32 slot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

        assertEq(_addr(vm.load(address(proxy), slot)), address(impl));
        assertEq(impl.proxiableUUID(), slot);
    }

    function test_Slot_ERC1967AdminAndBeacon() public {
        ERC1967Harness proxy = new ERC1967Harness();
        BeaconMock beacon = new BeaconMock(address(proxy));

        proxy.exposed_changeAdmin(owner);
        proxy.exposed_upgradeBeaconToAndCall(address(beacon), "");

        bytes32 adminSlot = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
        bytes32 beaconSlot = bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1);

        assertEq(_addr(vm.load(address(proxy), adminSlot)), owner);
        assertEq(_addr(vm.load(address(proxy), beaconSlot)), address(beacon));
    }

    function test_Slot_UpgradeableBeacon() public {
        UpgradeableBeacon beacon = new UpgradeableBeacon(owner, address(this));
        BeaconProxy proxy = new BeaconProxy(address(beacon), "");
        bytes32 beaconSlot = bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1);

        assertEq(_addr(vm.load(address(beacon), _erc7201("libsol.storage.UpgradeableBeacon"))), address(this));
        assertEq(_addr(vm.load(address(proxy), beaconSlot)), address(beacon));
    }

    // =========================================================================
    // Function Selectors
    // =========================================================================

    /// @dev Selectors hard-coded in assembly calls. Each is also exercised by a
    /// call that only succeeds if the selector is right.
    function test_CallSelectors_MatchInterfaces() public pure {
        assertEq(bytes4(0xb7009613), IAuthority.canCall.selector);
        assertEq(bytes4(0x7a9e5e4b), IAuthManaged.setAuthority.selector);
        assertEq(bytes4(0x5b14f183), IPauseAuthority.isPaused.selector);
        assertEq(bytes4(0x4b90364f), IPauseManaged.setPauseAuthority.selector);
        assertEq(bytes4(0x52d1902d), bytes4(keccak256("proxiableUUID()")));
        assertEq(bytes4(0x5c60da1b), IBeacon.implementation.selector);
    }
}
