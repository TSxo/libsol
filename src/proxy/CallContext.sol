// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/// @title CallContext
///
/// @author TSxo
///
/// @notice Modifiers that require code to run through a proxy, or not.
///
/// @dev Provides helpers to check the current call context.
abstract contract CallContext {
    // =========================================================================
    // Immutables
    // =========================================================================

    /// @dev The implementation address.
    address private immutable __self = address(this);

    // =========================================================================
    // Errors
    // =========================================================================

    /// @notice The code ran in the wrong context: directly instead of through a
    /// proxy, or through a proxy when it must be called directly.
    error CallContext__Unauthorized();

    // =========================================================================
    // Modifiers
    // =========================================================================

    /// @dev Reverts when running at the implementation's own address, that is,
    /// when called directly rather than through `delegatecall`. It does not
    /// check which contract delegated: any delegatecaller passes.
    modifier onlyProxy() {
        _assertProxyCall();
        _;
    }

    /// @dev Reverts unless running at the implementation's own address, that
    /// is, whenever the code runs through `delegatecall`.
    modifier notDelegated() {
        _assertImplementationCall();
        _;
    }

    // =========================================================================
    // Functions - Internal
    // =========================================================================

    /// @notice Returns the implementation contract address.
    ///
    /// @return The implementation contract address.
    function _self() internal view virtual returns (address) {
        return __self;
    }

    /// @notice Returns whether the execution is performed on the implementation
    /// contract.
    ///
    /// @return True if running at the implementation's own address.
    function _implementationCall() internal view virtual returns (bool) {
        return address(this) == __self;
    }

    /// @notice Asserts that the code is running at the implementation's own
    /// address, not through `delegatecall`.
    function _assertImplementationCall() internal view virtual {
        if (!_implementationCall()) _revert();
    }

    /// @notice Asserts that the code is running through `delegatecall`, at an
    /// address other than the implementation's own.
    function _assertProxyCall() internal view virtual {
        if (_implementationCall()) _revert();
    }

    // =========================================================================
    // Functions - Private
    // =========================================================================

    /// @notice Reverts with `CallContext__Unauthorized`.
    function _revert() private pure {
        assembly ("memory-safe") {
            mstore(0x00, 0x2574f2da) // `CallContext__Unauthorized()`
            revert(0x1c, 0x04)
        }
    }
}
