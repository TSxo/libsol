// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { Proxy } from "../Proxy.sol";
import { ERC1822 } from "./ERC1822.sol";

/// @title UUPSProxy
///
/// @author TSxo
///
/// @notice An ERC-1967 proxy for UUPS implementations.
///
/// @dev An ERC-1967 proxy designed for use with ERC-1822 UUPS implementations.
contract UUPSProxy is Proxy, ERC1822 {
    // =========================================================================
    // Functions - Constructor
    // =========================================================================

    /// @notice Initializes the contract with an implementation (logic) address.
    ///
    /// @param newImplementation The ERC-1822 compliant implementation contract.
    /// @param data              Initializer calldata to delegatecall, if any.
    ///
    /// @dev Requirements:
    /// - The implementation contract must be ERC-1822 compliant.
    ///
    /// If `data` is provided, it will be used to execute a delegatecall to the
    /// implementation contract. Any ETH sent stays in the proxy.
    ///
    /// Emits an `Upgraded` event.
    constructor(address newImplementation, bytes memory data) payable {
        _upgradeToAndCall(newImplementation, data);
    }

    // =========================================================================
    // Functions - Internal
    // =========================================================================

    /// @notice Returns the current implementation address.
    ///
    /// @return result The current implementation address.
    ///
    /// @dev Reads the slot directly rather than through `_getImplementation`:
    /// this runs on every proxied call, and the extra jump costs gas.
    function _implementation() internal view override returns (address result) {
        assembly ("memory-safe") {
            result := sload(IMPLEMENTATION_SLOT)
        }
    }
}
