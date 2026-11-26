// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { MutexAttack } from "test/mocks/MutexAttack.sol";

/// @notice The functions shared by `MutexHarness` and `MutexTransientHarness`,
/// so one test suite can run against both.
interface IMutexHarness {
    function increment() external;
    function count() external view returns (uint256);
    function unguardedToGuarded() external;
    function guardedToGuarded() external;
    function unguardedToGuardedRead() external view;
    function guardedToGuardedRead() external;
    function unguardedToExternal(MutexAttack attacker) external;
    function guardedToExternal(MutexAttack attacker) external;
    function exposed_isLocked() external view returns (bool);
}
