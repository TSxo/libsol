// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test, Vm } from "forge-std/Test.sol";

/// @notice Compares two sequences of recorded logs.
abstract contract LogAssertions is Test {
    /// @dev Requires the same logs, in order: the same topics and data. The
    /// emitters are not compared, since the two sides are different contracts.
    function _assertSameLogs(Vm.Log[] memory actualLogs, Vm.Log[] memory expectedLogs) internal pure {
        assertEq(actualLogs.length, expectedLogs.length, "log count");

        for (uint256 i; i < actualLogs.length; ++i) {
            assertEq(actualLogs[i].topics, expectedLogs[i].topics, "log topics");
            assertEq(actualLogs[i].data, expectedLogs[i].data, "log data");
        }
    }
}
