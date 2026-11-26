// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/// @title Proxy
///
/// @author TSxo
///
/// @notice Forwards every call to an implementation contract with
/// `delegatecall`.
///
/// @dev An abstract contract that implements the core proxy delegation pattern.
///
/// This contract forwards all calls to an implementation contract and returns
/// any results.
///
/// Inheriting contracts must implement the `_implementation()` function to
/// specify the target address.
abstract contract Proxy {
    // =========================================================================
    // Functions - Fallback
    // =========================================================================

    /// @notice Forwards all calls to the implementation contract.
    fallback() external payable virtual {
        _delegate(_implementation());
    }

    // =========================================================================
    // Functions - Internal
    // =========================================================================

    /// @notice Delegates the current call to the specified implementation
    /// address.
    ///
    /// @param implementation The implementation to delegate to.
    ///
    /// @dev Never hands control back to the Solidity code that called it. The
    /// assembly ends the current call, forwarding the implementation's return
    /// data on success or its revert data on failure, so any statement after
    /// `_delegate(...)` is unreachable.
    function _delegate(address implementation) internal virtual {
        assembly ("memory-safe") {
            // Calldata and returndata can exceed the 64-byte scratch space, so
            // they are copied past the free memory pointer.
            let ptr := mload(0x40)
            calldatacopy(ptr, 0x00, calldatasize())

            let success := delegatecall(gas(), implementation, ptr, calldatasize(), 0x00, 0x00)

            returndatacopy(ptr, 0x00, returndatasize())

            if iszero(success) { revert(ptr, returndatasize()) }

            return(ptr, returndatasize())
        }
    }

    /// @notice Returns the implementation contract address. Must be implemented
    /// by deriving contracts.
    ///
    /// @return result Address of the implementation contract.
    function _implementation() internal view virtual returns (address result);
}
