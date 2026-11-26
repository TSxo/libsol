// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/// @title Initializable
///
/// @author TSxo
///
/// @notice Guards the initializer functions of contracts that run behind a
/// proxy, so each one can run only once.
///
/// @dev A proxy cannot run its implementation's constructor, so upgradeable
/// contracts set themselves up in an initializer function instead. This
/// contract provides the guards:
/// - `initializer`: runs once, for the first version.
/// - `reinitializer(version)`: runs once for each later, higher version, for
///   migrations during an upgrade.
/// - `onlyInitializing`: for internal set-up functions that may only be called
///   from an initializer.
///
/// An implementation should call `_disableInitializers` in its constructor, so
/// that nobody can initialize the implementation contract itself:
///
/// ```solidity
/// constructor() {
///     _disableInitializers();
/// }
///
/// function initialize(address owner_) external initializer {
///     _initializeOwned(owner_);
/// }
/// ```
///
/// # Upgrade Compatible
///
/// The version and in-progress flag use ERC-7201 namespaced storage, so they
/// cannot collide with the inheriting contract's own storage.
abstract contract Initializable {
    // =========================================================================
    // Type Declarations
    // =========================================================================

    /// @dev Packed into one slot: `initialized` in bits 0-63, `initializing` in
    /// bit 64.
    ///
    /// @custom:storage-location erc7201:libsol.storage.Initializable
    struct InitializableStorage {
        uint64 initialized;
        bool initializing;
    }

    // =========================================================================
    // Constants
    // =========================================================================

    /// @dev keccak256(abi.encode(uint256(keccak256("libsol.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant INITIALIZABLE_SLOT = 0x228350bbb6ec721cd1284fd173ffc256e19d432aa81362824fe0149938a6fa00;

    /// @dev keccak256(bytes("Initialized(uint64)"))
    bytes32 private constant INITIALIZED = 0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2;

    /// @dev Mask for the `initialized` version, bits 0-63.
    uint256 private constant VERSION_MASK = 0xffffffffffffffff;

    /// @dev The `initializing` flag, bit 64.
    uint256 private constant INITIALIZING_BIT = 0x10000000000000000;

    // =========================================================================
    // Events
    // =========================================================================

    /// @notice Emitted when the contract is initialized to `version`.
    ///
    /// @param version The version the contract was initialized to.
    event Initialized(uint64 version);

    // =========================================================================
    // Errors
    // =========================================================================

    /// @notice The contract is already initialized to this version or later, or
    /// its initializers are disabled.
    error Initializable__InvalidInitialization();

    /// @notice The function may only run while the contract is initializing.
    error Initializable__NotInitializing();

    // =========================================================================
    // Modifiers
    // =========================================================================

    /// @dev Allows the function to run once, as version 1.
    ///
    /// Inside a constructor, several `initializer` functions may run in turn, so
    /// that a contract can combine parents that each use the modifier.
    modifier initializer() {
        bool isTopLevelCall = _beforeInitializer();
        _;
        if (isTopLevelCall) _endInitializing();
    }

    /// @dev Allows the function to run once, as `version`, provided the
    /// contract is not initializing and has not reached `version` yet. Use it
    /// for migrations when upgrading.
    modifier reinitializer(uint64 version) {
        _beforeReinitializer(version);
        _;
        _endInitializing();
    }

    /// @dev Allows the function to run only from inside an `initializer` or
    /// `reinitializer` function.
    modifier onlyInitializing() {
        _assertInitializing();
        _;
    }

    // =========================================================================
    // Functions - Internal
    // =========================================================================

    /// @notice Locks the contract against any further initialization. Call it in
    /// an implementation's constructor.
    ///
    /// @dev Emits an `Initialized` event the first time it takes effect.
    function _disableInitializers() internal virtual {
        assembly ("memory-safe") {
            let packed := sload(INITIALIZABLE_SLOT)

            if and(packed, INITIALIZING_BIT) {
                mstore(0x00, 0x7e02e85c) // `Initializable__InvalidInitialization()`
                revert(0x1c, 0x04)
            }

            if iszero(eq(and(packed, VERSION_MASK), VERSION_MASK)) {
                sstore(INITIALIZABLE_SLOT, VERSION_MASK)
                mstore(0x00, VERSION_MASK)
                log1(0x00, 0x20, INITIALIZED)
            }
        }
    }

    /// @notice Returns the version the contract has been initialized to.
    ///
    /// @return result The version; `type(uint64).max` once disabled.
    function _getInitializedVersion() internal view virtual returns (uint64 result) {
        assembly ("memory-safe") {
            result := and(sload(INITIALIZABLE_SLOT), VERSION_MASK)
        }
    }

    /// @notice Returns whether the contract is currently initializing.
    ///
    /// @return result True while an `initializer` or `reinitializer` runs.
    function _isInitializing() internal view virtual returns (bool result) {
        assembly ("memory-safe") {
            result := iszero(iszero(and(sload(INITIALIZABLE_SLOT), INITIALIZING_BIT)))
        }
    }

    /// @notice Asserts that the contract is currently initializing.
    function _assertInitializing() internal view virtual {
        assembly ("memory-safe") {
            if iszero(and(sload(INITIALIZABLE_SLOT), INITIALIZING_BIT)) {
                mstore(0x00, 0x8b4188b3) // `Initializable__NotInitializing()`
                revert(0x1c, 0x04)
            }
        }
    }

    // =========================================================================
    // Functions - Private
    // =========================================================================

    /// @notice Checks and records the start of an `initializer` call.
    ///
    /// @return isTopLevelCall True unless an initializer is already running.
    function _beforeInitializer() private returns (bool isTopLevelCall) {
        assembly ("memory-safe") {
            let packed := sload(INITIALIZABLE_SLOT)
            let initialized := and(packed, VERSION_MASK)

            isTopLevelCall := iszero(and(packed, INITIALIZING_BIT))

            // Allowed for the first top-level call, or for further initializers
            // while version 1 is being constructed (no code deployed yet).
            let isFirstCall := and(isTopLevelCall, iszero(initialized))
            let isConstruction := and(eq(initialized, 1), iszero(extcodesize(address())))

            if iszero(or(isFirstCall, isConstruction)) {
                mstore(0x00, 0x7e02e85c) // `Initializable__InvalidInitialization()`
                revert(0x1c, 0x04)
            }

            // Version 1, initializing.
            sstore(INITIALIZABLE_SLOT, or(1, INITIALIZING_BIT))

            if isTopLevelCall {
                mstore(0x00, 1)
                log1(0x00, 0x20, INITIALIZED)
            }
        }
    }

    /// @notice Checks and records the start of a `reinitializer` call.
    ///
    /// @param version The version being initialized to.
    function _beforeReinitializer(uint64 version) private {
        assembly ("memory-safe") {
            version := and(version, VERSION_MASK)

            let packed := sload(INITIALIZABLE_SLOT)

            // Not while initializing, and only to a higher version.
            if or(and(packed, INITIALIZING_BIT), iszero(lt(and(packed, VERSION_MASK), version))) {
                mstore(0x00, 0x7e02e85c) // `Initializable__InvalidInitialization()`
                revert(0x1c, 0x04)
            }

            sstore(INITIALIZABLE_SLOT, or(version, INITIALIZING_BIT))
            mstore(0x00, version)
            log1(0x00, 0x20, INITIALIZED)
        }
    }

    /// @notice Clears the `initializing` flag, keeping the version.
    function _endInitializing() private {
        assembly ("memory-safe") {
            sstore(INITIALIZABLE_SLOT, and(sload(INITIALIZABLE_SLOT), VERSION_MASK))
        }
    }
}
