// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";

import { CallContext } from "@tsxo/libsol/proxy/CallContext.sol";

import { CallContextHarness, CallContextProxy } from "test/harness/proxy/CallContextHarness.sol";

contract CallContextTest is Test {
    // =========================================================================
    // State
    // =========================================================================

    CallContextHarness callContext;
    CallContextProxy proxy;

    // =========================================================================
    // Set Up
    // =========================================================================

    function setUp() public {
        callContext = new CallContextHarness();
        proxy = new CallContextProxy(address(callContext));
    }

    // =========================================================================
    // Test - Call Context
    // =========================================================================

    function test_ImplementationCall_OnImplementation() public view {
        assertTrue(callContext.exposed_implementationCall());
    }

    function test_ImplementationCall_ThroughProxy() public view {
        // Wrapped.
        CallContextHarness asImpl = CallContextHarness(address(proxy));

        bool result = asImpl.exposed_implementationCall();
        assertFalse(result);

        // Static Call.
        bytes memory implCall = abi.encodeCall(CallContextHarness.exposed_implementationCall, ());

        (bool success, bytes memory data) = address(proxy).staticcall(implCall);
        bool isImplCall = abi.decode(data, (bool));

        assertTrue(success);
        assertFalse(isImplCall);
    }

    function test_Self_OnImplementation() public view {
        address self = callContext.exposed_selfAddress();
        assertEq(self, address(callContext));
    }

    function test_Self_ThroughProxy() public view {
        CallContextHarness asImpl = CallContextHarness(address(proxy));

        address self = asImpl.exposed_selfAddress();
        assertEq(self, address(callContext));
    }

    function test_NotDelegated_OnImplementation() public view {
        callContext.exposed_assertImplCall();
    }

    function test_RevertWhen_NotDelegated_CalledThroughProxy() public {
        CallContextHarness asImpl = CallContextHarness(address(proxy));
        bytes4 err = CallContext.CallContext__Unauthorized.selector;

        vm.expectRevert(err);
        asImpl.exposed_assertImplCall();
    }

    function test_RevertWhen_OnlyProxy_CalledOnImplementation() public {
        bytes4 err = CallContext.CallContext__Unauthorized.selector;
        vm.expectRevert(err);
        callContext.exposed_assertProxyCall();
    }

    function test_OnlyProxyModifier_ThroughProxy() public view {
        CallContextHarness asImpl = CallContextHarness(address(proxy));

        asImpl.exposed_assertProxyCall();
    }
}
