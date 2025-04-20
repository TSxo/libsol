// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/// @title CallContext
///
/// @author TSxo
///
/// @dev Provides helpers to check the current call context.
///
/// # Acknowledgements
///
/// Heavy inspiration is taken from:
/// - OpenZeppelin;
/// - Solmate; and
/// - Solady.
///
/// Thank you.
abstract contract CallContext {
    // -------------------------------------------------------------------------
    // State

    /// @dev The implementation address.
    address private immutable __self = address(this);

    // -------------------------------------------------------------------------
    // Errors

    /// @notice Raised when a call occurs in an unauthorized context.
    error CallContext__Unauthorized();

    // -------------------------------------------------------------------------
    // Modifiers

    /// @dev Reverts if the execution is not performed through a delegate call.
    modifier onlyProxy() virtual {
        _assertProxyCall();
        _;
    }

    /// @dev Reverts if the execution is performed through a delegate call.
    modifier notDelegated() virtual {
        _assertImplementationCall();
        _;
    }

    // -------------------------------------------------------------------------
    // Functions - Internal

    /// @notice Returns the implementation contract address.
    ///
    /// @return The implementation contract address.
    function _self() internal view virtual returns (address) {
        return __self;
    }

    /// @notice Returns whether the execution is performed on the implementation
    /// contract.
    ///
    /// @return True if the execution is performed on the implementation contract,
    /// false otherwise.
    function _implementationCall() internal view virtual returns (bool) {
        return address(this) == __self;
    }

    /// @notice Asserts that the execution is not performed through a delegate call.
    function _assertImplementationCall() internal view virtual {
        if (!_implementationCall()) _revert();
    }

    /// @notice Asserts that the execution is performed through a delegate call.
    function _assertProxyCall() internal view virtual {
        if (_implementationCall()) _revert();
    }

    // -------------------------------------------------------------------------
    // Functions - Private

    /// @notice Reverts with `CallContext__Unauthorized`.
    function _revert() private pure {
        assembly ("memory-safe") {
            mstore(0x00, 0x2574f2da) // `CallContext__Unauthorized()`
            revert(0x1c, 0x04)
        }
    }
}
