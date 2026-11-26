// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { IPauseManaged } from "./IPauseManaged.sol";
import { IPauseAuthority } from "./IPauseAuthority.sol";

/// @title PauseManaged
///
/// @author TSxo
///
/// @notice Blocks functions while an external Pause Authority reports this
/// contract as paused.
///
/// @dev This contract provides a `notPaused` modifier. Functions in the
/// inheriting contract that apply this modifier will have their access
/// controlled according to the pause status returned by a "Pause Authority". A
/// Pause Authority is any contract that implements the `IPauseAuthority`
/// interface - such as `PauseManager`.
///
/// The Pause Authority is set during initialization and updatable only by the
/// current Pause Authority.
///
/// # Upgrade Compatible
///
/// This contract uses ERC-7201 namespaced storage, making it compatible with
/// upgradeable contract architectures. Note, it does not enforce any
/// restrictions against reinitialization, leaving such protection mechanisms up
/// to the inheriting contract.
abstract contract PauseManaged is IPauseManaged {
    // =========================================================================
    // Type Declarations
    // =========================================================================

    /// @custom:storage-location erc7201:libsol.storage.PauseManaged
    struct PauseManagedStorage {
        IPauseAuthority pauseAuthority;
    }

    // =========================================================================
    // Constants
    // =========================================================================

    /// @dev keccak256(abi.encode(uint256(keccak256("libsol.storage.PauseManaged")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant PAUSE_MANAGED_SLOT = 0xc66347d0ffe6d5df1f35d40c7bb569f122b483125d91db20f2994199cdded400;

    /// @dev keccak256(bytes("PauseAuthorityUpdated(address,address)"))
    bytes32 private constant PAUSE_AUTH_UPDATED = 0x10c33fee6662fbe5d47879269625f98f56358218ae1332e9ce326a30c16b3414;

    /// @dev bytes4(keccak256(bytes("isPaused(address)")))
    bytes32 private constant IS_PAUSED = 0x5b14f18300000000000000000000000000000000000000000000000000000000;

    // =========================================================================
    // Modifiers
    // =========================================================================

    /// @dev Asserts that the contract is not paused according to the Pause
    /// Authority.
    modifier notPaused() {
        _assertNotPaused();
        _;
    }

    // =========================================================================
    // Functions - Init
    // =========================================================================

    /// @notice Initializes the contract by setting the initial Pause Authority.
    ///
    /// @param initialAuthority The initial Pause Authority.
    function _initializePauseManaged(address initialAuthority) internal virtual {
        _setPauseAuthority(initialAuthority);
    }

    // =========================================================================
    // Functions - Public
    // =========================================================================

    /// @inheritdoc IPauseManaged
    function setPauseAuthority(address newAuthority) public virtual {
        assembly ("memory-safe") {
            if iszero(eq(caller(), sload(PAUSE_MANAGED_SLOT))) {
                mstore(0x00, 0x1066ef6e) // `PauseManaged__Unauthorized()`
                revert(0x1c, 0x04)
            }
        }

        _setPauseAuthority(newAuthority);
    }

    /// @inheritdoc IPauseManaged
    function pauseAuthority() public view virtual returns (address result) {
        assembly ("memory-safe") {
            result := sload(PAUSE_MANAGED_SLOT)
        }
    }

    // =========================================================================
    // Functions - Internal
    // =========================================================================

    /// @notice Updates the contract's Pause Authority.
    ///
    /// @param newAuthority The address of the new Authority.
    ///
    /// @dev Internal function with no access control. Requirements:
    /// - `newAuthority` must be a contract. Setting an account without code
    ///   would permanently lock every function that uses `notPaused`.
    ///
    /// Emits a `PauseAuthorityUpdated` event.
    function _setPauseAuthority(address newAuthority) internal virtual {
        assembly ("memory-safe") {
            newAuthority := shr(96, shl(96, newAuthority))

            // An Authority without code would answer every `isPaused` with
            // empty return data, and could never call `setPauseAuthority` to be
            // replaced, locking every `notPaused` function permanently.
            if iszero(extcodesize(newAuthority)) {
                mstore(0x00, 0x863e3599) // `PauseManaged__InvalidAuthority()`
                revert(0x1c, 0x04)
            }

            log3(0x00, 0x00, PAUSE_AUTH_UPDATED, sload(PAUSE_MANAGED_SLOT), newAuthority)
            sstore(PAUSE_MANAGED_SLOT, newAuthority)
        }
    }

    /// @notice Asserts that the contract is not paused according to the Pause
    /// Authority.
    function _assertNotPaused() internal view virtual {
        assembly ("memory-safe") {
            let manager := sload(PAUSE_MANAGED_SLOT)

            mstore(0x00, IS_PAUSED)
            mstore(0x04, address())

            let success := staticcall(gas(), manager, 0x00, 0x24, 0x00, 0x20)

            // Bubble up the Authority's revert reason.
            if iszero(success) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0x00, returndatasize())
                revert(ptr, returndatasize())
            }

            if iszero(eq(returndatasize(), 0x20)) {
                mstore(0x00, 0x863e3599) // `PauseManaged__InvalidAuthority()`
                revert(0x1c, 0x04)
            }

            // Any non-zero word counts as paused, so malformed data fails
            // closed.
            if mload(0x00) {
                mstore(0x00, 0xd6bb310d) // `PauseManaged__Paused()`
                revert(0x1c, 0x04)
            }
        }
    }
}
