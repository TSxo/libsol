// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { ERC1967Logic } from "../ERC1967/ERC1967Logic.sol";
import { Proxy } from "../Proxy.sol";

/// @title UUPSProxy
///
/// @author TSxo
///
/// @dev An ERC-1967 proxy designed for use with ERC-1822 UUPS implementations.
///
/// # Acknowledgements
///
/// Heavy inspiration is taken from:
/// - OpenZeppelin;
/// - Solmate; and
/// - Solady.
///
/// Thank you.
contract UUPSProxy is Proxy, ERC1967Logic {
    // -------------------------------------------------------------------------
    // Functions - Constructor

    /// @notice Initializes the contract with an implementation (logic) address.
    ///
    /// @dev Requirements:
    /// - The implementation contract must be ERC-1822 compliant.
    ///
    /// If `data` is provided, it will be used to execute a delegatecall to the
    /// implementation contract.
    ///
    /// Emits an `Upgraded` event.
    constructor(address newImplementation, bytes memory data) payable {
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

            let len := mload(data)
            if len {
                let ptr := add(data, 0x20)

                success := delegatecall(gas(), newImplementation, ptr, len, 0x00, 0x00)
                returndatacopy(0x00, 0x00, returndatasize())

                if iszero(success) { revert(0x00, returndatasize()) }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Functions - Internal

    /// @notice Returns the current implementation address.
    ///
    /// @return result The current implementation address.
    function _implementation() internal view override returns (address result) {
        assembly ("memory-safe") {
            result := sload(IMPLEMENTATION_SLOT)
        }
    }
}
