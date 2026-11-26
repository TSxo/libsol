// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/// @title ERC1967
///
/// @author TSxo
///
/// @notice The ERC-1967 proxy storage slots, with the events, errors, and
/// internal helpers that read and change them.
///
/// @dev ERC-1967 fixes three storage slots so that tools can find what a proxy
/// points to:
/// - The implementation the proxy delegates to.
/// - The admin allowed to upgrade it, for proxies managed by an admin.
/// - The beacon that supplies the implementation, for beacon proxies.
///
/// Both proxies and implementations inherit this contract.
///
/// The helpers have no access control. `_upgradeToAndCall` checks a new
/// implementation with `_validateImplementation`, which by default only
/// requires code.
///
/// See: https://eips.ethereum.org/EIPS/eip-1967
abstract contract ERC1967 {
    // =========================================================================
    // Constants
    // =========================================================================

    /// @dev bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @dev bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /// @dev bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1)
    bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /// @dev keccak256(bytes("Upgraded(address)"))
    bytes32 internal constant UPGRADED = 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b;

    /// @dev keccak256(bytes("AdminChanged(address,address)"))
    bytes32 internal constant ADMIN_CHANGED = 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f;

    /// @dev keccak256(bytes("BeaconUpgraded(address)"))
    bytes32 internal constant BEACON_UPGRADED = 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e;

    // =========================================================================
    // Events
    // =========================================================================

    /// @notice Emitted when the implementation address is updated.
    ///
    /// @param implementation The new implementation address.
    event Upgraded(address indexed implementation);

    /// @notice Emitted when the admin changes.
    ///
    /// @param previousAdmin The old admin.
    /// @param newAdmin      The new admin.
    event AdminChanged(address previousAdmin, address newAdmin);

    /// @notice Emitted when the beacon changes.
    ///
    /// @param beacon The new beacon.
    event BeaconUpgraded(address indexed beacon);

    // =========================================================================
    // Errors
    // =========================================================================

    /// @notice The new implementation is not acceptable: it has no code or, for
    /// UUPS, its `proxiableUUID()` does not return the ERC-1967 slot.
    error ERC1967__UpgradeFailed();

    /// @notice The new admin is the zero address.
    error ERC1967__InvalidAdmin();

    /// @notice The new beacon has no code, or the implementation it reports
    /// has none.
    error ERC1967__InvalidBeacon();

    // =========================================================================
    // Functions - Internal
    // =========================================================================

    /// @notice Returns the current implementation address.
    ///
    /// @return result The implementation address.
    function _getImplementation() internal view virtual returns (address result) {
        assembly ("memory-safe") {
            result := sload(IMPLEMENTATION_SLOT)
        }
    }

    /// @notice Sets the implementation to `newImplementation`, then
    /// delegatecalls it with `data`, if any.
    ///
    /// @param newImplementation The new implementation.
    /// @param data              Calldata to run after upgrading, if any.
    ///
    /// @dev Internal function with no access control. Any ETH sent is available
    /// to the delegatecall made with `data`. If `data` is empty, the ETH stays
    /// in the proxy.
    ///
    /// Requirements:
    /// - `newImplementation` must pass `_validateImplementation`.
    ///
    /// Emits an `Upgraded` event.
    function _upgradeToAndCall(address newImplementation, bytes memory data) internal virtual {
        _validateImplementation(newImplementation);

        assembly ("memory-safe") {
            newImplementation := shr(96, shl(96, newImplementation))
            log2(0x00, 0x00, UPGRADED, newImplementation)
            sstore(IMPLEMENTATION_SLOT, newImplementation)
        }

        _delegateCallIfData(newImplementation, data);
    }

    /// @notice Checks that `newImplementation` may be upgraded to.
    ///
    /// @param newImplementation The implementation being upgraded to.
    ///
    /// @dev Requirements:
    /// - `newImplementation` must have code.
    function _validateImplementation(address newImplementation) internal view virtual {
        assembly ("memory-safe") {
            if iszero(extcodesize(newImplementation)) {
                mstore(0x00, 0xef8e491e) // `ERC1967__UpgradeFailed()`
                revert(0x1c, 0x04)
            }
        }
    }

    /// @notice Returns the current admin.
    ///
    /// @return result The admin address.
    function _getAdmin() internal view virtual returns (address result) {
        assembly ("memory-safe") {
            result := sload(ADMIN_SLOT)
        }
    }

    /// @notice Sets the admin to `newAdmin`.
    ///
    /// @param newAdmin The new admin.
    ///
    /// @dev Internal function with no access control.
    ///
    /// Requirements:
    /// - `newAdmin` must not be the zero address.
    ///
    /// Emits an `AdminChanged` event.
    function _changeAdmin(address newAdmin) internal virtual {
        assembly ("memory-safe") {
            newAdmin := shr(96, shl(96, newAdmin))

            if iszero(newAdmin) {
                mstore(0x00, 0xaeb18f4f) // `ERC1967__InvalidAdmin()`
                revert(0x1c, 0x04)
            }

            // The slot is shared by convention, so clean what another
            // contract may have left in it.
            mstore(0x00, shr(96, shl(96, sload(ADMIN_SLOT))))
            mstore(0x20, newAdmin)
            log1(0x00, 0x40, ADMIN_CHANGED)
            sstore(ADMIN_SLOT, newAdmin)
        }
    }

    /// @notice Returns the current beacon.
    ///
    /// @return result The beacon address.
    function _getBeacon() internal view virtual returns (address result) {
        assembly ("memory-safe") {
            result := sload(BEACON_SLOT)
        }
    }

    /// @notice Sets the beacon to `newBeacon`, then delegatecalls the beacon's
    /// implementation with `data`, if any.
    ///
    /// @param newBeacon The new beacon.
    /// @param data      Calldata to run after upgrading, if any.
    ///
    /// @dev Internal function with no access control. Any ETH sent is available
    /// to the delegatecall made with `data`. If `data` is empty, the ETH stays
    /// in the proxy.
    ///
    /// Requirements:
    /// - `newBeacon` must have code.
    /// - `newBeacon.implementation()` must return a contract with code.
    ///
    /// Emits a `BeaconUpgraded` event.
    function _upgradeBeaconToAndCall(address newBeacon, bytes memory data) internal virtual {
        address implementation;

        assembly ("memory-safe") {
            newBeacon := shr(96, shl(96, newBeacon))
            mstore(0x00, 0x5c60da1b) // `implementation()`

            // `implementation()` must succeed and return one word: an account
            // without code "succeeds" with no return data, so this also
            // rejects a beacon without code.
            let success := staticcall(gas(), newBeacon, 0x1c, 0x04, 0x00, 0x20)
            implementation := shr(96, shl(96, mload(0x00)))

            let returnedWord := eq(returndatasize(), 0x20)
            let hasCode := iszero(iszero(extcodesize(implementation)))

            if iszero(and(and(success, returnedWord), hasCode)) {
                mstore(0x00, 0x2608d5c6) // `ERC1967__InvalidBeacon()`
                revert(0x1c, 0x04)
            }

            log2(0x00, 0x00, BEACON_UPGRADED, newBeacon)
            sstore(BEACON_SLOT, newBeacon)
        }

        _delegateCallIfData(implementation, data);
    }

    // =========================================================================
    // Functions - Private
    // =========================================================================

    /// @notice Delegatecalls `target` with `data` if `data` is not empty,
    /// bubbling up any revert.
    function _delegateCallIfData(address target, bytes memory data) private {
        assembly ("memory-safe") {
            let len := mload(data)
            if len {
                if iszero(delegatecall(gas(), target, add(data, 0x20), len, 0x00, 0x00)) {
                    // Revert data can exceed the scratch space, so it is copied
                    // past the free memory pointer.
                    let ptr := mload(0x40)
                    returndatacopy(ptr, 0x00, returndatasize())
                    revert(ptr, returndatasize())
                }
            }
        }
    }
}
