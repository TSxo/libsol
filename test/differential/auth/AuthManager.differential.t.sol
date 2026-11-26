// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { IAuthManager } from "@tsxo/libsol/auth/managed/IAuthManager.sol";
import { IAuthority } from "@tsxo/libsol/auth/managed/IAuthority.sol";

import { AuthManagerHarness } from "test/harness/auth/AuthManagerHarness.sol";
import { AuthManagerReferenceHarness } from "test/harness/auth/AuthManagerReferenceHarness.sol";
import { CounterTarget } from "test/mocks/CounterTarget.sol";
import { ScriptedMock } from "test/mocks/ScriptedMock.sol";

import { DifferentialBase } from "../DifferentialBase.sol";

/// @notice Compares `AuthManager` with the reference for arbitrary
/// combinations of user roles, function roles, and the public and closed flags,
/// on arbitrary target functions.
contract AuthManagerDifferentialTest is DifferentialBase {
    enum Action {
        SetUserRole,
        SetRoleAccess,
        SetFunctionPublic,
        SetFunctionClosed,
        SetAuthority
    }

    /// @dev One fuzzed step. The index fields pick from the pools below.
    struct Step {
        uint8 action;
        bool byOwner;
        uint8 target;
        bool decrement;
        uint8 role;
        bool enabled;
        uint8 newAuthority;
    }

    uint256 constant ROLE_COUNT = 254;

    address owner = makeAddr("owner");
    address user = makeAddr("user");

    AuthManagerHarness manager;
    AuthManagerReferenceHarness referenceManager;

    /// @dev Both implementations, driven through the shared interface.
    IAuthManager[2] both;

    function setUp() public {
        manager = new AuthManagerHarness(owner);
        referenceManager = new AuthManagerReferenceHarness(owner);
        both = [IAuthManager(address(manager)), IAuthManager(address(referenceManager))];
    }

    /// @dev Applies every role set in `userMask` and `accessMask` (bits 0-253;
    /// bits 254 and 255 are ignored, as they are not roles) to both, then
    /// compares every view. The target and selector are fuzzed too: to the
    /// manager they are only storage keys, so the result must not depend on
    /// them.
    function testFuzz_AnyBitmasks_MatchReference(
        uint256 userMask,
        uint256 accessMask,
        address target,
        bytes4 selector,
        bool isPublic,
        bool isClosed,
        uint8 probe
    ) public {
        vm.startPrank(owner);

        for (uint256 i; i < both.length; ++i) {
            IAuthManager auth = both[i];

            for (uint256 role; role < ROLE_COUNT; ++role) {
                if ((userMask >> role) & 1 == 1) {
                    auth.setUserRole(user, uint8(role), true);
                }

                if ((accessMask >> role) & 1 == 1) {
                    auth.setRoleAccess(target, selector, uint8(role), true);
                }
            }

            auth.setFunctionPublic(target, selector, isPublic);
            auth.setFunctionClosed(target, selector, isClosed);
        }

        vm.stopPrank();

        _assertViewsMatch(target, selector, probe);
    }

    /// @dev Runs a sequence of setter calls on both, by the owner or an
    /// outsider, with valid and invalid roles and well-formed and malformed
    /// targets for `setAuthority`. Requires the same success, return or revert
    /// data, and events for every call, and the same access afterwards.
    function testFuzz_AnySequence_MatchesReference(Step[STEPS] calldata steps) public {
        // As `setAuthority` targets: accepts with no reply, accepts with a
        // reply, reverts with data, has no code. To the other setters they are
        // only storage keys.
        address[4] memory targets = [
            address(new ScriptedMock(false, "")),
            address(new ScriptedMock(false, abi.encode(true))),
            address(new ScriptedMock(true, abi.encodeWithSignature("Error(string)", "nope"))),
            makeAddr("eoa")
        ];

        // Both role boundaries (0 and 253) and both flag positions (254 and
        // 255), which every setter must reject as roles.
        uint8[5] memory roles = [0, 1, 253, 254, 255];

        for (uint256 i; i < STEPS; ++i) {
            Step calldata step = steps[i];
            Action action = Action(bound(step.action, 0, uint256(type(Action).max)));
            address caller = step.byOwner ? owner : user;
            address target = targets[bound(step.target, 0, targets.length - 1)];
            bytes4 selector = step.decrement ? CounterTarget.decrement.selector : CounterTarget.increment.selector;
            uint8 role = roles[bound(step.role, 0, roles.length - 1)];

            bytes memory data;
            if (action == Action.SetUserRole) {
                data = abi.encodeCall(IAuthManager.setUserRole, (user, role, step.enabled));
            } else if (action == Action.SetRoleAccess) {
                data = abi.encodeCall(IAuthManager.setRoleAccess, (target, selector, role, step.enabled));
            } else if (action == Action.SetFunctionPublic) {
                data = abi.encodeCall(IAuthManager.setFunctionPublic, (target, selector, step.enabled));
            } else if (action == Action.SetFunctionClosed) {
                data = abi.encodeCall(IAuthManager.setFunctionClosed, (target, selector, step.enabled));
            } else {
                address newAuthority = targets[bound(step.newAuthority, 0, targets.length - 1)];
                data = abi.encodeCall(IAuthority.setAuthority, (target, newAuthority));
            }

            _callBoth(address(manager), address(referenceManager), caller, data);
            _assertViewsMatch(target, selector, role);
        }

        for (uint256 t; t < targets.length; ++t) {
            _assertViewsMatch(targets[t], CounterTarget.increment.selector, roles[t % roles.length]);
            _assertViewsMatch(targets[t], CounterTarget.decrement.selector, roles[(t + 1) % roles.length]);
        }
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    /// @dev Compares every view of the manager (`actual`) with the reference
    /// (`expected`).
    function _assertViewsMatch(address target, bytes4 selector, uint8 probe) internal view {
        bool actual = manager.canCall(user, target, selector);
        bool expected = referenceManager.canCall(user, target, selector);
        assertEq(actual, expected, "canCall");

        actual = manager.isFunctionPublic(target, selector);
        expected = referenceManager.isFunctionPublic(target, selector);
        assertEq(actual, expected, "isFunctionPublic");

        actual = manager.isFunctionClosed(target, selector);
        expected = referenceManager.isFunctionClosed(target, selector);
        assertEq(actual, expected, "isFunctionClosed");

        actual = manager.hasRole(user, probe);
        expected = referenceManager.hasRole(user, probe);
        assertEq(actual, expected, "hasRole");

        actual = manager.roleHasAccess(target, selector, probe);
        expected = referenceManager.roleHasAccess(target, selector, probe);
        assertEq(actual, expected, "roleHasAccess");

        uint256 actualMask = manager.userRoles(user);
        uint256 expectedMask = referenceManager.userRoles(user);
        assertEq(actualMask, expectedMask, "userRoles");

        actualMask = manager.functionAccess(target, selector);
        expectedMask = referenceManager.functionAccess(target, selector);
        assertEq(actualMask, expectedMask, "functionAccess");
    }
}
