// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { CallContext } from "../CallContext.sol";
import { ERC1822 } from "./ERC1822.sol";

/// @title UUPSImplementation
///
/// @author TSxo
///
/// @notice Base for UUPS (ERC-1822) implementation contracts, which upgrade the
/// proxy they run behind.
///
/// @dev An ERC-1822 and ERC-1967 compliant UUPS implementation contract.
/// Designed to be used with an ERC-1967 proxy.
abstract contract UUPSImplementation is CallContext, ERC1822 {
    // =========================================================================
    // Functions - External
    // =========================================================================

    /// @notice Returns the slot at which the implementation address is stored.
    ///
    /// @return The ERC-1967 implementation slot.
    ///
    /// @dev Requirements:
    /// - Not callable through a proxy. This prevents upgrades to a proxy
    ///   contract.
    ///
    /// The reply only says where the implementation is stored. It cannot show
    /// that a new implementation keeps an upgrade path, which ERC-1822 leaves
    /// to the integrator.
    ///
    /// See https://eips.ethereum.org/EIPS/eip-1822
    function proxiableUUID() external view virtual notDelegated returns (bytes32) {
        return IMPLEMENTATION_SLOT;
    }

    // =========================================================================
    // Functions - Public
    // =========================================================================

    /// @notice Upgrades the implementation of the proxy to `newImplementation`
    /// and executes the function call, if any, encoded in `data`.
    ///
    /// @param newImplementation The new ERC-1822 compliant implementation.
    /// @param data              Calldata to run after upgrading, if any.
    ///
    /// @dev Requirements:
    /// - Only callable through a proxy.
    /// - The caller must be authorized to perform the upgrade.
    /// - The `newImplementation` must be ERC-1822 compliant.
    ///
    /// Any ETH sent is available to the delegatecall made with `data`. If
    /// `data` is empty, the ETH stays in the proxy.
    ///
    /// Emits an `Upgraded` event.
    function upgradeToAndCall(address newImplementation, bytes calldata data) public payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCall(newImplementation, data);
    }

    // =========================================================================
    // Functions - Internal
    // =========================================================================

    /// @notice Called by `upgradeToAndCall` to check whether the `msg.sender`
    /// is authorized to perform the upgrade.
    ///
    /// @param newImplementation The implementation being upgraded to.
    ///
    /// @dev Override this function with your preferred access check. Example:
    ///
    /// ```solidity
    /// function _authorizeUpgrade(address) internal override onlyOwner {}
    /// ```
    function _authorizeUpgrade(address newImplementation) internal virtual;

    /// @notice Reverts unless the call came through a proxy whose ERC-1967
    /// implementation slot holds this contract.
    ///
    /// @dev Without the slot check, a UUPS implementation reached through a
    /// beacon proxy, or any other delegatecaller, would write an
    /// implementation slot that the caller never reads, so the upgrade would
    /// succeed and change nothing.
    function _assertProxyCall() internal view virtual override {
        super._assertProxyCall();

        address self = _self();
        assembly ("memory-safe") {
            if iszero(eq(sload(IMPLEMENTATION_SLOT), self)) {
                mstore(0x00, 0x2574f2da) // `CallContext__Unauthorized()`
                revert(0x1c, 0x04)
            }
        }
    }
}
