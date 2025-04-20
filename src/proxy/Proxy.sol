// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/// @title Proxy
///
/// @author TSxo
///
/// @dev An abstract contract that implements the core proxy delegation pattern.
///
/// This contract forwards all calls to an implementation contract and returns
/// any results.
///
/// Inheriting contracts must implement the `_implementation()` function to
/// specify the target address.
///
/// # Acknowledgements
///
/// Heavy inspiration is taken from:
/// - OpenZeppelin;
/// - Solmate; and
/// - Solady.
///
/// Thank you.
abstract contract Proxy {
    // -------------------------------------------------------------------------
    // Functions - Fallback

    /// @notice Forwards all calls to the implementation contract.
    fallback() external payable virtual {
        _delegate(_implementation());
    }

    // -------------------------------------------------------------------------
    // Functions - Internal

    /// @notice Delegates the current call to the specified implementation address.
    ///
    /// @param implementation Address of the implementation contract to delegate to.
    function _delegate(address implementation) internal virtual {
        assembly ("memory-safe") {
            calldatacopy(0x00, 0x00, calldatasize())

            let success := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            returndatacopy(0x00, 0x00, returndatasize())

            if iszero(success) { revert(0x00, returndatasize()) }

            return(0x00, returndatasize())
        }
    }

    /// @notice Returns the implementation contract address. Must be implemented
    /// by deriving contracts.
    ///
    /// @return result Address of the implementation contract.
    function _implementation() internal view virtual returns (address result);
}
