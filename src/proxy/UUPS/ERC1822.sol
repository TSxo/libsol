// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { ERC1967 } from "../ERC1967/ERC1967.sol";

/// @title ERC1822
///
/// @author TSxo
///
/// @notice Accepts only UUPS (ERC-1822) implementations when upgrading.
///
/// @dev Overrides `_validateImplementation` so that `_upgradeToAndCall` only
/// accepts an implementation whose `proxiableUUID()` returns the ERC-1967
/// implementation slot. This stops an upgrade to a contract that could not
/// upgrade the proxy again, which would freeze it. Shared by `UUPSProxy` and
/// `UUPSImplementation`.
///
/// See: https://eips.ethereum.org/EIPS/eip-1822
abstract contract ERC1822 is ERC1967 {
    // =========================================================================
    // Functions - Internal
    // =========================================================================

    /// @notice Checks that `newImplementation` is a UUPS implementation.
    ///
    /// @param newImplementation The implementation being upgraded to.
    ///
    /// @dev Requirements:
    /// - `newImplementation.proxiableUUID()` must return the ERC-1967
    ///   implementation slot.
    function _validateImplementation(address newImplementation) internal view virtual override {
        assembly ("memory-safe") {
            mstore(0x00, 0x52d1902d) // `proxiableUUID()`

            let success := staticcall(gas(), newImplementation, 0x1c, 0x04, 0x00, 0x20)

            // `proxiableUUID()` must succeed, return one 32-byte word, and
            // report the ERC-1967 implementation slot. An account without code
            // "succeeds" with no return data, so the size check rejects it too.
            let returnedWord := eq(returndatasize(), 0x20)
            let reportsSlot := eq(mload(0x00), IMPLEMENTATION_SLOT)

            if iszero(and(and(success, returnedWord), reportsSlot)) {
                mstore(0x00, 0xef8e491e) // `ERC1967__UpgradeFailed()`
                revert(0x1c, 0x04)
            }
        }
    }
}
