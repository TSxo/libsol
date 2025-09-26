// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IPauseManaged } from "./IPauseManaged.sol";
import { IPauseManager } from "./IPauseManager.sol";
import { IPauseAuthority } from "./IPauseAuthority.sol";

/// @title PauseManager
///
/// @author TSxo
///
/// @dev This contract provides an effecient and flexible solution for managing
/// the paused status of a system.
///
/// It allows for both global pausing of all managed contracts and individual
/// pausing of specific target contracts.
///
/// # Target Contracts
///
/// A smart contract under the control of a `PauseManager` instance is known as
/// target. Target contracts will inherit from the `PauseManaged` contract and
/// implement the `notPaused` modifier on all functions that should be subject
/// to management.
///
/// # Pause States
///
/// The system supports two levels of pausing:
/// - Global Pause: A single boolean state that, when true, indicates all target
///   contracts managed by this instance should be considered paused.
/// - Target-Specific Pause: Each target contract can have its own boolean
///   pause state. This allows for granular control, pausing individual contracts
///   without affecting others.
///
/// Important: A target is considered paused if either the global pause is active
/// or its specific pause state is true.
///
/// # Owner
///
/// All the state managed by this system can be modified by the owner of this
/// instance. It is expected that this account will be highly secured.
///
/// To determine the owner, this contract performs a staticcall to its own
/// `owner()` function. This allows compatibility with any contract that adheres
/// to the ERC-173 ownership standard.
///
/// # Upgrade Compatible
///
/// This contract utilizes ERC-7201 namespaced storage, making it compatible with
/// upgradeable contract architectures.
///
/// # Acknowledgements
///
/// Heavy inspiration is taken from:
/// - OpenZeppelin;
/// - Solmate; and
/// - Solady.
///
/// Thank you.
abstract contract PauseManager is IPauseManager, IPauseAuthority {
    // -------------------------------------------------------------------------
    // Type Declarations

    /// @custom:storage-location erc7201:libsol.storage.PauseManager
    struct PauseManagerStorage {
        bool globallyPaused;
        mapping(address => bool) paused;
    }

    // -------------------------------------------------------------------------
    // State

    /// @dev keccak256(abi.encode(uint256(keccak256("libsol.storage.PauseManager")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant PAUSE_MANAGER_SLOT = 0x03dc5d0b43282563b8a1e9222195b8d69795a494aec70f1259eac0c5aa6af700;

    /// @dev keccak256(bytes("TargetStatusUpdated(address,bool)"))
    bytes32 private constant TARGET_STATUS_UPDATED = 0xd8ba28ed4dd67a3f5c8a1ce3137372814fda6470bd2966f4c2301313e28065a7;

    /// @dev keccak256(bytes("GlobalStatusUpdated(bool)"))
    bytes32 private constant GLOBAL_STATUS_UPDATED = 0x09c6d75db2cb0af58bfe81628cc0eec5951d4ae5cbed61e39c87332b5f0cd077;

    /// @dev keccak256(bytes("PauseAuthorityUpdated(address,address)"))
    bytes32 private constant PAUSE_AUTH_UPDATED = 0x10c33fee6662fbe5d47879269625f98f56358218ae1332e9ce326a30c16b3414;

    // -------------------------------------------------------------------------
    // Functions - Public

    /// @inheritdoc IPauseManager
    function setTargetPaused(address target, bool enabled) public virtual {
        _assertPauseManagerOwner();
        _setTargetPaused(target, enabled);
    }

    /// @inheritdoc IPauseManager
    function setGloballyPaused(bool enabled) public virtual {
        _assertPauseManagerOwner();
        _setGloballyPaused(enabled);
    }

    /// @inheritdoc IPauseAuthority
    function setPauseAuthority(address target, address newAuthority) public virtual {
        _assertPauseManagerOwner();

        assembly ("memory-safe") {
            newAuthority := shr(96, shl(96, newAuthority))
            mstore(0x00, shl(224, 0x4b90364f)) // `setPauseAuthority(address)`
            mstore(0x04, newAuthority)

            let success := call(gas(), target, 0x00, 0x00, 0x24, 0x00, 0x00)

            if iszero(success) { revert(0x00, 0x00) }
            if iszero(eq(returndatasize(), 0x00)) { revert(0x00, 0x00) }

            log3(0x00, 0x00, PAUSE_AUTH_UPDATED, target, newAuthority)
        }
    }

    /// @inheritdoc IPauseAuthority
    function isPaused(address target) public view virtual returns (bool result) {
        return isGloballyPaused() || isTargetPaused(target);
    }

    /// @inheritdoc IPauseManager
    function isTargetPaused(address target) public view virtual returns (bool result) {
        assembly ("memory-safe") {
            mstore(0x00, target)
            mstore(0x20, add(PAUSE_MANAGER_SLOT, 1))
            result := sload(keccak256(0x00, 0x40))
        }
    }

    /// @inheritdoc IPauseManager
    function isGloballyPaused() public view virtual returns (bool result) {
        assembly ("memory-safe") {
            result := sload(PAUSE_MANAGER_SLOT)
        }
    }

    // -------------------------------------------------------------------------
    // Functions - Internal

    /// @notice Sets the paused status of a target contract.
    ///
    /// @param target   The address of the target contract.
    /// @param enabled  Whether to pause the target contract.
    ///
    /// @dev Internal function with no access control or restriction.
    ///
    /// Emits a `TargetStatusUpdated` event.
    function _setTargetPaused(address target, bool enabled) internal virtual {
        assembly ("memory-safe") {
            target := shr(96, shl(96, target))
            mstore(0x00, target)
            mstore(0x20, add(PAUSE_MANAGER_SLOT, 1))
            let slot := keccak256(0x00, 0x40)

            sstore(slot, enabled)

            mstore(0x00, enabled)
            log2(0x00, 0x20, TARGET_STATUS_UPDATED, target)
        }
    }

    /// @notice Sets the global paused status.
    ///
    /// @param enabled Whether to enable the global pause.
    ///
    /// @dev Internal function with no access control or restriction.
    ///
    /// Emits a `GlobalStatusUpdated` event.
    function _setGloballyPaused(bool enabled) internal virtual {
        assembly ("memory-safe") {
            sstore(PAUSE_MANAGER_SLOT, enabled)

            mstore(0x00, enabled)
            log1(0x00, 0x20, GLOBAL_STATUS_UPDATED)
        }
    }

    /// @notice Asserts that the caller is the owner of the contract.
    function _assertPauseManagerOwner() internal virtual {
        assembly ("memory-safe") {
            mstore(0x00, 0x8da5cb5b) // `owner()`
            let success := staticcall(gas(), address(), 0x1c, 0x04, 0x00, 0x20)

            if iszero(success) { revert(0x00, 0x00) }
            if iszero(eq(returndatasize(), 0x20)) { revert(0x00, 0x00) }

            if iszero(eq(caller(), mload(0x00))) {
                mstore(0x0, 0xe2813822) // `PauseManager__Unauthorized()`
                revert(0x1c, 0x04)
            }
        }
    }
}
