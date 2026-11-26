// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { ERC1967 } from "../ERC1967/ERC1967.sol";
import { Proxy } from "../Proxy.sol";

/// @title BeaconProxy
///
/// @author TSxo
///
/// @notice A proxy that asks a beacon, on every call, which implementation to
/// delegate to.
///
/// @dev Many proxies can share one beacon, so that upgrading the beacon
/// upgrades them all. Each call costs one extra `staticcall` to the beacon.
///
/// The beacon is fixed at construction. It is kept in an immutable, which
/// saves a storage read on every call, and also written to the ERC-1967
/// beacon slot so that tools can find it.
///
/// The proxy trusts its beacon completely. It does not check on each call
/// that the implementation has code: a beacon that reported an account without
/// code would make every call succeed and do nothing. `UpgradeableBeacon`
/// rejects such implementations.
///
/// See: https://eips.ethereum.org/EIPS/eip-1967#beacon-contract-address
contract BeaconProxy is Proxy, ERC1967 {
    // =========================================================================
    // Immutables
    // =========================================================================

    /// @dev The beacon, fixed at construction.
    address private immutable __beacon;

    // =========================================================================
    // Functions - Constructor
    // =========================================================================

    /// @notice Points the proxy at `beacon` and runs `data`, if any, on the
    /// beacon's implementation.
    ///
    /// @param beacon The beacon.
    /// @param data   Initializer calldata to delegatecall, if any.
    ///
    /// @dev Requirements:
    /// - `beacon` must have code, and its `implementation()` must return a
    ///   contract with code.
    ///
    /// Emits a `BeaconUpgraded` event.
    // forge-lint: disable-next-line(missing-zero-check) -- `_upgradeBeaconToAndCall` rejects accounts without code.
    constructor(address beacon, bytes memory data) payable {
        _upgradeBeaconToAndCall(beacon, data);
        __beacon = beacon;
    }

    // =========================================================================
    // Functions - Internal
    // =========================================================================

    /// @notice Returns the implementation the beacon currently reports.
    ///
    /// @return result The implementation address.
    ///
    /// @dev Requirements:
    /// - The beacon's `implementation()` must succeed and return one word.
    ///   Otherwise the beacon's revert is bubbled up, or the call reverts with
    ///   `ERC1967__InvalidBeacon`.
    function _implementation() internal view override returns (address result) {
        address beacon = __beacon;

        assembly ("memory-safe") {
            mstore(0x00, 0x5c60da1b) // `implementation()`

            if iszero(staticcall(gas(), beacon, 0x1c, 0x04, 0x00, 0x20)) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0x00, returndatasize())
                revert(ptr, returndatasize())
            }

            if iszero(eq(returndatasize(), 0x20)) {
                mstore(0x00, 0x2608d5c6) // `ERC1967__InvalidBeacon()`
                revert(0x1c, 0x04)
            }

            result := shr(96, shl(96, mload(0x00)))
        }
    }
}
