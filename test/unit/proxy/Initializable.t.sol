// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";

import { Initializable } from "@tsxo/libsol/proxy/Initializable.sol";

import {
    ConstructorInitializableHarness,
    DisabledInitializableHarness,
    InitializableHarness,
    NestedInitializableHarness
} from "test/harness/proxy/InitializableHarness.sol";

interface TestEvents {
    event Initialized(uint64 version);
}

contract InitializableTest is Test, TestEvents {
    InitializableHarness target;

    function setUp() public {
        target = new InitializableHarness();
    }

    // =========================================================================
    // Test - initializer
    // =========================================================================

    function test_Initialize_RunsOnce() public {
        vm.expectEmit(address(target));
        emit Initialized(1);
        target.initialize(7);

        assertEq(target.value(), 7);
        assertEq(target.parentCalls(), 1);
        assertEq(target.exposed_initializedVersion(), 1);
        assertFalse(target.exposed_isInitializing());

        vm.expectRevert(Initializable.Initializable__InvalidInitialization.selector);
        target.initialize(8);
    }

    function test_RevertWhen_OnlyInitializing_NotInitializing() public {
        vm.expectRevert(Initializable.Initializable__NotInitializing.selector);
        target.exposed_initializeParentDirectly();
    }

    /// @dev Several `initializer` functions may run in turn in one constructor.
    function test_Initializer_AllowsSequentialCallsDuringConstruction() public {
        ConstructorInitializableHarness built = new ConstructorInitializableHarness();
        assertEq(built.a(), 1);
        assertEq(built.b(), 2);

        // Once deployed, the contract counts as initialized.
        vm.expectRevert(Initializable.Initializable__InvalidInitialization.selector);
        built.initialize();
    }

    /// @dev Inside a constructor, an `initializer` may call another. The inner
    /// one neither emits a second `Initialized` nor ends the outer one early.
    function test_Initializer_AllowsNestedCallsDuringConstruction() public {
        vm.recordLogs();
        NestedInitializableHarness built = new NestedInitializableHarness(true);
        assertEq(vm.getRecordedLogs().length, 1, "one Initialized event");

        assertEq(built.outer(), 1);
        assertEq(built.inner(), 1);
        assertEq(built.exposed_initializedVersion(), 1);
        assertFalse(built.exposed_isInitializing());
    }

    /// @dev Once deployed, nesting is no longer allowed: the inner
    /// `initializer` reverts, and with it the whole call.
    function test_RevertWhen_Initializer_NestedAfterDeployment() public {
        NestedInitializableHarness built = new NestedInitializableHarness(false);

        vm.expectRevert(Initializable.Initializable__InvalidInitialization.selector);
        built.initialize();

        assertEq(built.exposed_initializedVersion(), 0);
    }

    // =========================================================================
    // Test - reinitializer
    // =========================================================================

    function test_Reinitialize_RunsOncePerHigherVersion() public {
        target.initialize(1);

        vm.expectEmit(address(target));
        emit Initialized(2);
        target.reinitialize(2, 20);
        assertEq(target.value(), 20);
        assertEq(target.exposed_initializedVersion(), 2);

        vm.expectRevert(Initializable.Initializable__InvalidInitialization.selector);
        target.reinitialize(2, 21);

        target.reinitialize(5, 50);
        assertEq(target.exposed_initializedVersion(), 5);

        // Versions cannot go backwards, and `initializer` cannot run again.
        vm.expectRevert(Initializable.Initializable__InvalidInitialization.selector);
        target.reinitialize(3, 30);

        vm.expectRevert(Initializable.Initializable__InvalidInitialization.selector);
        target.initialize(1);
    }

    function testFuzz_Reinitialize_RequiresHigherVersion(uint64 first, uint64 second) public {
        first = uint64(bound(first, 1, type(uint64).max - 1));

        target.reinitialize(first, 1);

        if (second <= first) vm.expectRevert(Initializable.Initializable__InvalidInitialization.selector);
        target.reinitialize(second, 2);
    }

    // =========================================================================
    // Test - _disableInitializers
    // =========================================================================

    function test_RevertWhen_Initialize_InitializersAreDisabled() public {
        vm.expectEmit(address(target));
        emit Initialized(type(uint64).max);
        target.exposed_disableInitializers();

        assertEq(target.exposed_initializedVersion(), type(uint64).max);

        vm.expectRevert(Initializable.Initializable__InvalidInitialization.selector);
        target.initialize(1);

        vm.expectRevert(Initializable.Initializable__InvalidInitialization.selector);
        target.reinitialize(type(uint64).max, 1);
    }

    /// @dev Disabling twice is a no-op the second time: no second event.
    function test_DisableInitializers_IsIdempotent() public {
        target.exposed_disableInitializers();

        vm.recordLogs();
        target.exposed_disableInitializers();
        assertEq(vm.getRecordedLogs().length, 0);
    }

    function test_RevertWhen_DisableInitializers_Initializing() public {
        vm.expectRevert(Initializable.Initializable__InvalidInitialization.selector);
        target.disableWhileInitializing();
    }

    /// @dev The pattern for implementations: lock in the constructor.
    function test_RevertWhen_Initialize_ImplementationIsDisabled() public {
        DisabledInitializableHarness implementation = new DisabledInitializableHarness();
        assertEq(implementation.exposed_initializedVersion(), type(uint64).max);

        vm.expectRevert(Initializable.Initializable__InvalidInitialization.selector);
        implementation.initialize();
    }
}
