// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Vm } from "forge-std/Test.sol";

import { CounterTarget } from "test/mocks/CounterTarget.sol";
import { LogAssertions } from "test/utils/LogAssertions.sol";

/// @notice Shared helpers for comparing an assembly implementation in `src/`
/// with its readable Solidity reference in `test/reference/`.
///
/// @dev Sequence tests take a fuzzed array of `STEPS` steps. Each step is a
/// small struct whose fields `bound()` maps onto an action and its arguments,
/// so the fuzzer's edge values reach every field and a failure prints, and
/// shrinks, as a readable list of steps.
abstract contract DifferentialBase is LogAssertions {
    /// @dev Steps per fuzzed sequence: enough for grants, revocations, and
    /// hand-overs to interact.
    uint256 internal constant STEPS = 16;

    /// @dev Calls `data` on both contracts as `caller`, then requires the same
    /// outcome: the same success, the same return or revert data, and the same
    /// logs (topics and data; the emitters differ).
    ///
    /// @return success Whether the call succeeded, on both.
    function _callBoth(address actual, address expected, address caller, bytes memory data)
        internal
        returns (bool success)
    {
        vm.recordLogs();
        vm.prank(caller);
        (bool actualSuccess, bytes memory actualData) = actual.call(data);
        Vm.Log[] memory actualLogs = vm.getRecordedLogs();

        vm.recordLogs();
        vm.prank(caller);
        (bool expectedSuccess, bytes memory expectedData) = expected.call(data);
        Vm.Log[] memory expectedLogs = vm.getRecordedLogs();

        assertEq(actualSuccess, expectedSuccess, "success");
        assertEq(actualData, expectedData, "return or revert data");
        _assertSameLogs(actualLogs, expectedLogs);

        return actualSuccess;
    }

    /// @dev `account` as a 32-byte word with junk in the 96 bits above the
    /// address, as a malformed beacon might return it. Implementations must
    /// read only the low 160 bits.
    function _dirtyAddressWord(address account) internal pure returns (uint256) {
        return uint256(uint160(account)) | (uint256(0xff) << 200);
    }

    /// @dev Calldata for `CounterTarget`, the implementation behind the proxy
    /// tests: none, a write of `value`, an increment, a decrement that reverts
    /// once the count is zero, or a selector nothing implements.
    function _counterCall(uint8 kind, uint256 value) internal pure returns (bytes memory) {
        uint256 k = bound(kind, 0, 4);
        if (k == 0) return "";
        if (k == 1) return abi.encodeCall(CounterTarget.setCount, (value));
        if (k == 2) return abi.encodeCall(CounterTarget.increment, ());
        if (k == 3) return abi.encodeCall(CounterTarget.decrement, ());
        return hex"deadbeef";
    }
}
