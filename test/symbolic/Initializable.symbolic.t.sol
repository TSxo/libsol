// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";

import { Initializable } from "@tsxo/libsol/proxy/Initializable.sol";

import { InitializableHarness } from "test/harness/proxy/InitializableHarness.sol";

/// @notice Symbolic proofs for `Initializable`'s packed state: the version in
/// bits 0-63 and the `initializing` flag in bit 64.
///
/// Each check writes a symbolic state word into the contract's slot with
/// `vm.store`, so the solver proves the rule for every reachable state and
/// every version, not for sampled ones. Run with `just symbolic`.
contract InitializableSymbolicTest is Test {
    uint256 constant VERSION_MASK = type(uint64).max;
    uint256 constant INITIALIZING_BIT = uint256(1) << 64;

    InitializableHarness initializable;
    bytes32 slot;

    function setUp() public {
        initializable = new InitializableHarness();
        slot = keccak256(abi.encode(uint256(keccak256("libsol.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff));
    }

    /// @dev Stores `state`, limited to the bits the contract uses.
    function _store(uint256 state) internal {
        vm.assume(state < (INITIALIZING_BIT << 1));
        vm.store(address(initializable), slot, bytes32(state));
    }

    function _state() internal view returns (uint256) {
        return uint256(vm.load(address(initializable), slot));
    }

    /// @dev On a deployed contract, `initializer` runs only from the fresh state,
    /// and leaves version 1 with the flag cleared. Otherwise it reverts and
    /// changes nothing.
    function check_Initializer_FollowsRule(uint256 state) public {
        _store(state);

        (bool success, bytes memory data) =
            address(initializable).call(abi.encodeCall(InitializableHarness.initialize, (7)));

        assertEq(success, state == 0);
        if (success) {
            assertEq(_state(), 1);
        } else {
            assertEq(data, abi.encodeWithSelector(Initializable.Initializable__InvalidInitialization.selector));
            assertEq(_state(), state);
        }
    }

    /// @dev `reinitializer(version)` runs only when not initializing and below
    /// `version`, and leaves exactly `version` with the flag cleared. Otherwise
    /// it reverts and changes nothing.
    function check_Reinitializer_FollowsRule(uint256 state, uint64 version) public {
        _store(state);

        (bool success, bytes memory data) =
            address(initializable).call(abi.encodeCall(InitializableHarness.reinitialize, (version, 7)));

        bool initializing = state & INITIALIZING_BIT != 0;
        assertEq(success, !initializing && (state & VERSION_MASK) < version);

        if (success) {
            assertEq(_state(), version);
        } else {
            assertEq(data, abi.encodeWithSelector(Initializable.Initializable__InvalidInitialization.selector));
            assertEq(_state(), state);
        }
    }

    /// @dev `_disableInitializers` succeeds unless initializing, and always
    /// leaves the maximum version with the flag cleared.
    function check_DisableInitializers_FollowsRule(uint256 state) public {
        _store(state);

        (bool success,) =
            address(initializable).call(abi.encodeCall(InitializableHarness.exposed_disableInitializers, ()));

        assertEq(success, state & INITIALIZING_BIT == 0);
        assertEq(_state(), success ? VERSION_MASK : state);
    }

    /// @dev `onlyInitializing` admits a call exactly when the flag is set,
    /// whatever the version.
    function check_OnlyInitializing_FollowsFlag(uint256 state) public {
        _store(state);

        (bool success,) =
            address(initializable).call(abi.encodeCall(InitializableHarness.exposed_initializeParentDirectly, ()));

        assertEq(success, state & INITIALIZING_BIT != 0);
    }
}
