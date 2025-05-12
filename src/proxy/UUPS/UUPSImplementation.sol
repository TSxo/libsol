// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { CallContext } from "../../mixins/CallContext.sol";
import { ERC1967Logic } from "../ERC1967/ERC1967Logic.sol";

/// @title UUPSImplementation
///
/// @author TSxo
///
/// @dev An ERC-1822 and ERC-1967 compliant UUPS implementation contract. Designed
/// to be used with an ERC-1967 proxy.
///
/// # Acknowledgements
///
/// Heavy inspiration is taken from:
/// - OpenZeppelin;
/// - Solmate; and
/// - Solady.
///
/// Thank you.
abstract contract UUPSImplementation is CallContext, ERC1967Logic {
    // -------------------------------------------------------------------------
    // Functions - External

    /// @notice Returns the slot at which the implementation address is stored.
    ///
    /// @dev Requirements:
    /// - Not callable through a proxy. This prevents upgrades to a proxy contract.
    ///
    /// See https://eips.ethereum.org/EIPS/eip-1822
    function proxiableUUID() external view virtual notDelegated returns (bytes32) {
        return IMPLEMENTATION_SLOT;
    }

    // -------------------------------------------------------------------------
    // Functions - Public

    /// @notice Upgrades the implementation of the proxy to `newImplementation`
    /// and executes the function call, if any, encoded in `data`.
    ///
    /// @dev Requirements:
    /// - Only callable through a proxy.
    /// - The caller must be authorized to perform the upgrade.
    /// - The `newImplementation` must be ERC-1822 compliant.
    ///
    /// Emits an `Upgraded` event.
    function upgradeToAndCall(address newImplementation, bytes calldata data) public payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);

        assembly ("memory-safe") {
            mstore(0x00, 0x52d1902d) // `proxiableUUID()`

            let success := staticcall(gas(), newImplementation, 0x1c, 0x04, 0x00, 0x20)

            if iszero(success) { revert(0x00, 0x00) }
            if iszero(eq(returndatasize(), 0x20)) { revert(0x00, 0x00) }

            if iszero(eq(mload(0x00), IMPLEMENTATION_SLOT)) {
                mstore(0x00, 0x5f73959e) // `ERC1967Logic__UpgradeFailed()`
                revert(0x1c, 0x04)
            }

            log2(0x00, 0x00, UPGRADED, newImplementation)
            sstore(IMPLEMENTATION_SLOT, newImplementation)

            if data.length {
                let ptr := mload(0x40)
                calldatacopy(ptr, data.offset, data.length)

                success := delegatecall(gas(), newImplementation, ptr, data.length, 0x00, 0x00)
                if iszero(success) {
                    returndatacopy(ptr, 0x00, returndatasize())
                    revert(ptr, returndatasize())
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Functions - Internal

    /// @notice Called by `upgradeToAndCall` to check whether the `msg.sender`
    /// is authorized to perform the upgrade.
    ///
    /// @dev Override this function with your preferred access check. Example:
    ///
    /// ```solidity
    /// function _authorizeUpgrade(address) internal override onlyOwner {}
    /// ```
    function _authorizeUpgrade(address newImplementation) internal virtual;
}
