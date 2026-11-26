// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { stdError } from "forge-std/StdError.sol";
import { Test } from "forge-std/Test.sol";

import { CounterTarget } from "test/mocks/CounterTarget.sol";
import { EchoTarget, RevertEchoTarget } from "test/mocks/EchoTarget.sol";
import { ProxyHarness } from "test/harness/proxy/ProxyHarness.sol";

interface TestEvents {
    event Received(uint256 val);
    event Count(uint256 n);
}

contract ProxyTest is Test, TestEvents {
    // =========================================================================
    // State
    // =========================================================================

    CounterTarget counter;
    ProxyHarness proxy;

    /// @dev The proxy, called through the implementation's interface.
    CounterTarget proxied;

    // =========================================================================
    // Set Up
    // =========================================================================

    function setUp() public {
        counter = new CounterTarget();
        proxy = new ProxyHarness(address(counter));
        proxied = CounterTarget(payable(address(proxy)));
    }

    // =========================================================================
    // Test - Fallback
    // =========================================================================

    function test_Fallback_ForwardsReturnData() public {
        proxied.setCount(10);

        (bool success, bytes memory data) = address(proxy).staticcall(abi.encodeWithSelector(proxied.count.selector));

        assertTrue(success);
        assertEq(data, abi.encode(uint256(10)));
    }

    /// @dev The implementation's code runs against the proxy's storage, and
    /// its events come from the proxy.
    function test_Fallback_WritesProxyStorage() public {
        vm.expectEmit(address(proxy));
        emit Count(1);
        proxied.increment();

        assertEq(proxied.count(), 1);
        assertEq(counter.count(), 0, "implementation storage untouched");
    }

    function test_Fallback_ReturnsNoDataForVoidCalls() public {
        (bool success, bytes memory data) = address(proxy).call(abi.encodeCall(CounterTarget.increment, ()));

        assertTrue(success);
        assertEq(data.length, 0);
    }

    function test_RevertWhen_Fallback_ImplementationReverts() public {
        vm.expectRevert(stdError.arithmeticError);
        proxied.decrement();
    }

    /// @dev `CounterTarget` has no fallback, so an unknown selector reverts
    /// without data, through the proxy as it would directly.
    function test_RevertWhen_Fallback_SelectorIsUnknown() public {
        vm.expectRevert(bytes(""));
        (bool revertsAsExpected,) = address(proxy).call(abi.encodeWithSignature("notExist()"));
        assertTrue(revertsAsExpected, "expectRevert: call did not revert");
    }

    function test_Fallback_ForwardsValue() public {
        vm.deal(address(this), 2 ether);

        // Plain ETH reaches the implementation's `receive`.
        vm.expectEmit(address(proxy));
        emit Received(1 ether);
        (bool success,) = address(proxy).call{ value: 1 ether }("");
        assertTrue(success);

        // ETH with calldata reaches a payable function.
        vm.expectEmit(address(proxy));
        emit Received(1 ether);
        proxied.fundMe{ value: 1 ether }();

        assertEq(address(proxy).balance, 2 ether);
        assertEq(address(counter).balance, 0);
    }

    // =========================================================================
    // Test - Wide Data
    // =========================================================================

    /// @dev Calldata and return data longer than the 64 bytes of scratch space
    /// pass through unchanged. The target echoes its calldata, so one check
    /// covers both directions.
    function testFuzz_Fallback_ForwardsWideCalldataAndReturnData(uint256 length, uint256 seed) public {
        ProxyHarness echo = new ProxyHarness(address(new EchoTarget()));
        bytes memory payload = _payload(bound(length, 65, 1024), seed);

        (bool success, bytes memory result) = address(echo).call(payload);

        assertTrue(success);
        assertEq(result, payload);
    }

    function testFuzz_RevertWhen_Fallback_ForwardsWideRevertData(uint256 length, uint256 seed) public {
        ProxyHarness echo = new ProxyHarness(address(new RevertEchoTarget()));
        bytes memory payload = _payload(bound(length, 65, 1024), seed);

        (bool success, bytes memory result) = address(echo).call(payload);

        assertFalse(success);
        assertEq(result, payload);
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    /// @dev `length` bytes derived from `seed`, so a failing run reproduces.
    function _payload(uint256 length, uint256 seed) internal pure returns (bytes memory result) {
        result = new bytes(length);
        for (uint256 i; i < length; i += 32) {
            bytes32 word = keccak256(abi.encode(seed, i));
            for (uint256 j; j < 32 && i + j < length; ++j) {
                result[i + j] = word[j];
            }
        }
    }
}
