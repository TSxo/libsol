pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";
import { CallContext } from "@tsxo/libsol/mixins/CallContext.sol";
import { CallContextMock, CallContextProxy } from "@tsxo/libsol/mocks/mixins/CallContextMock.sol";

contract CallContextTest is Test {
    // -------------------------------------------------------------------------
    // State

    CallContextMock callContext;
    CallContextProxy proxy;

    // -------------------------------------------------------------------------
    // Set Up

    function setUp() public {
        callContext = new CallContextMock();
        proxy = new CallContextProxy(address(callContext));
    }

    // -------------------------------------------------------------------------
    // Tests

    function test_ImplementationCall_OnImplementation() public view {
        assert(callContext.implementationCall());
    }

    function test_ImplementationCall_ThroughProxy() public view {
        // Wrapped.
        CallContextMock asImpl = CallContextMock(address(proxy));

        bool result = asImpl.implementationCall();
        assert(!result);

        // Static Call.
        bytes memory implCall = abi.encodeWithSignature("implementationCall()");

        (bool success, bytes memory data) = address(proxy).staticcall(implCall);
        bool isImplCall = abi.decode(data, (bool));

        assert(success);
        assert(!isImplCall);
    }

    function test_Self_OnImplementation() public view {
        address self = callContext.selfAddress();
        assertEq(self, address(callContext));
    }

    function test_Self_ThroughProxy() public view {
        CallContextMock asImpl = CallContextMock(address(proxy));

        address self = asImpl.selfAddress();
        assertEq(self, address(callContext));
    }

    function test_NotDelegated_OnImplementation() public view {
        callContext.assertImplCall();
    }

    function test_NotDelegatedModifier_ThroughProxy() public {
        CallContextMock asImpl = CallContextMock(address(proxy));
        bytes4 err = CallContext.CallContext__Unauthorized.selector;

        vm.expectRevert(err);
        asImpl.assertImplCall();
    }

    function test_OnlyProxyModifier_OnImplementation() public {
        bytes4 err = CallContext.CallContext__Unauthorized.selector;
        vm.expectRevert(err);
        callContext.assertProxyCall();
    }

    function test_OnlyProxyModifier_ThroughProxy() public view {
        CallContextMock asImpl = CallContextMock(address(proxy));

        asImpl.assertProxyCall();
    }
}
