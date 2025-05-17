// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IPausable } from "./IPausable.sol";

/// @title Pausable
///
/// @author TSxo
///
/// @dev This contract provides `notPaused` and `paused` modifiers. Functions in
/// the inheriting contract that apply these modifiers will have their access
/// controlled according to the pause status of this contract.
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
abstract contract Pausable is IPausable {
    // -------------------------------------------------------------------------
    // Type Declarations

    /// @custom:storage-location erc7201:libsol.storage.Pausable
    struct PausableStorage {
        bool paused;
    }

    // -------------------------------------------------------------------------
    // State

    /// @dev keccak256(abi.encode(uint256(keccak256("libsol.storage.Pausable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant PAUSABLE_SLOT = 0xac4021300b8ef24d08da24939f15f0130671c139a482dd2c4b17a1c6d1040400;

    /// @dev keccak256(bytes("Paused(address,bool)"))
    bytes32 private constant PAUSED = 0xe8699cf681560fd07de85543bd994263f4557bdc5179dd702f256d15fd083e1d;

    // -------------------------------------------------------------------------
    // Modifiers

    /// @dev Asserts that the contract is not paused.
    modifier notPaused() virtual {
        _assertNotPaused();
        _;
    }

    /// @dev Asserts that the contract is paused.
    modifier paused() virtual {
        _assertPaused();
        _;
    }

    // -------------------------------------------------------------------------
    // Functions - Public

    /// @inheritdoc IPausable
    function isPaused() public view virtual returns (bool result) {
        assembly ("memory-safe") {
            result := sload(PAUSABLE_SLOT)
        }
    }

    // -------------------------------------------------------------------------
    // Functions - Internal

    /// @notice Sets the pause state.
    ///
    /// @param enabled True to pause, false to resume.
    ///
    /// @dev Internal function with no access control or restriction.
    ///
    /// Emits a `Paused` event.
    function _setPaused(bool enabled) internal virtual {
        assembly ("memory-safe") {
            sstore(PAUSABLE_SLOT, enabled)

            mstore(0x00, enabled)
            log2(0x00, 0x20, PAUSED, caller())
        }
    }

    /// @notice Asserts that the contract is paused.
    function _assertPaused() internal virtual {
        assembly ("memory-safe") {
            if iszero(sload(PAUSABLE_SLOT)) {
                mstore(0x00, 0x152387d7) // `Pausable__PauseExpected()`
                revert(0x1c, 0x04)
            }
        }
    }

    /// @notice Asserts that the contract is not paused.
    function _assertNotPaused() internal virtual {
        assembly ("memory-safe") {
            if sload(PAUSABLE_SLOT) {
                mstore(0x00, 0x7fb0d7b9) // `Pausable__PauseEnforced()`
                revert(0x1c, 0x04)
            }
        }
    }
}
