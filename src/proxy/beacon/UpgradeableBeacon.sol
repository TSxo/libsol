// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { Owned } from "../../auth/Owned.sol";
import { IBeacon } from "./IBeacon.sol";
import { IUpgradeableBeacon } from "./IUpgradeableBeacon.sol";

/// @title UpgradeableBeacon
///
/// @author TSxo
///
/// @notice A beacon whose owner chooses the implementation for every
/// `BeaconProxy` that points to it.
///
/// @dev One call to `upgradeTo` upgrades all of the beacon's proxies at once.
/// The owner therefore controls the code of every one of them, so treat the
/// beacon's ownership like an upgrade key.
///
/// Ownership comes from `Owned`: a single owner, transferred in one step.
///
/// # Upgrade Compatible
///
/// This contract uses ERC-7201 namespaced storage, like the rest of libsol,
/// although a beacon is normally deployed directly rather than behind a proxy.
contract UpgradeableBeacon is Owned, IUpgradeableBeacon {
    // =========================================================================
    // Type Declarations
    // =========================================================================

    /// @custom:storage-location erc7201:libsol.storage.UpgradeableBeacon
    struct UpgradeableBeaconStorage {
        address implementation;
    }

    // =========================================================================
    // Constants
    // =========================================================================

    /// @dev keccak256(abi.encode(uint256(keccak256("libsol.storage.UpgradeableBeacon")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant UPGRADEABLE_BEACON_SLOT =
        0x4686f27d86633e135cf9715c90dd04116fe3f63fd25d6c820e01b1742b799000;

    /// @dev keccak256(bytes("Upgraded(address)"))
    bytes32 private constant UPGRADED = 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b;

    // =========================================================================
    // Functions - Constructor
    // =========================================================================

    /// @notice Sets the owner and the first implementation.
    ///
    /// @param initialOwner          The beacon's owner.
    /// @param initialImplementation The first implementation.
    ///
    /// @dev Requirements:
    /// - `initialImplementation` must have code.
    ///
    /// Emits an `OwnershipTransferred` and an `Upgraded` event.
    constructor(address initialOwner, address initialImplementation) {
        _initializeOwned(initialOwner);
        _setImplementation(initialImplementation);
    }

    // =========================================================================
    // Functions - Public
    // =========================================================================

    /// @notice Points every proxy that uses this beacon at `newImplementation`.
    ///
    /// @param newImplementation The new implementation.
    ///
    /// @dev Requirements:
    /// - Only callable by the owner.
    /// - `newImplementation` must have code.
    ///
    /// Emits an `Upgraded` event.
    function upgradeTo(address newImplementation) public virtual onlyOwner {
        _setImplementation(newImplementation);
    }

    /// @inheritdoc IBeacon
    function implementation() public view virtual returns (address result) {
        assembly ("memory-safe") {
            result := sload(UPGRADEABLE_BEACON_SLOT)
        }
    }

    // =========================================================================
    // Functions - Internal
    // =========================================================================

    /// @notice Sets the implementation.
    ///
    /// @param newImplementation The new implementation.
    ///
    /// @dev Internal function with no access control.
    ///
    /// Requirements:
    /// - `newImplementation` must have code.
    ///
    /// Emits an `Upgraded` event.
    function _setImplementation(address newImplementation) internal virtual {
        assembly ("memory-safe") {
            newImplementation := shr(96, shl(96, newImplementation))

            if iszero(extcodesize(newImplementation)) {
                mstore(0x00, 0x9bca69da) // `UpgradeableBeacon__InvalidImplementation()`
                revert(0x1c, 0x04)
            }

            log2(0x00, 0x00, UPGRADED, newImplementation)
            sstore(UPGRADEABLE_BEACON_SLOT, newImplementation)
        }
    }
}
