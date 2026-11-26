// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/// @title MutexTransient
///
/// @author TSxo
///
/// @notice A reentrancy guard that keeps its lock in transient storage
/// (EIP-1153).
///
/// @dev Provides mechanisms to guard against reentrancy attacks, using
/// transient storage (EIP-1153).
///
/// A drop-in alternative to `Mutex` with the same modifiers, internal
/// functions, and error. The lock lives in transient storage, so it costs far
/// less than a storage write and is cleared automatically at the end of every
/// transaction.
///
/// # Requirements
///
/// - Solidity 0.8.24 or later, compiled for the Cancun EVM or later.
/// - A chain that supports `TSTORE` and `TLOAD`. On chains without transient
///   storage, use `Mutex`.
///
/// # Guards
///
/// Exposes two modifiers: `lock` for write operations and `whenUnlocked` for
/// reads.
///
/// The `lock` modifier acquires a lock before function execution and releases
/// it afterward. While locked, no other function using `lock` or `whenUnlocked`
/// can be called.
///
/// The `whenUnlocked` modifier ensures no lock is held during calls to view
/// functions, preventing read-level reentrancy.
///
/// Functions guarded by these modifiers cannot directly call each other. To
/// navigate this issue, extract reusable logic into modifier-free internal or
/// private functions and compose calls to them from a single guarded entry
/// point.
///
/// # Upgrade Compatible
///
/// The lock uses an ERC-7201 namespaced transient slot and needs no
/// initialization, so it is safe behind a proxy.
abstract contract MutexTransient {
    // =========================================================================
    // Constants
    // =========================================================================

    /// @dev keccak256(abi.encode(uint256(keccak256("libsol.transient.Mutex")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MUTEX_TRANSIENT_SLOT = 0x42b0305ab4af60164b6d2b5afbe059191c59fbb61cd866a82d535b06cab12e00;

    // =========================================================================
    // Errors
    // =========================================================================

    /// @notice The lock is held: a guarded function was entered again.
    error Mutex__Locked();

    // =========================================================================
    // Modifiers
    // =========================================================================

    /// @dev Guards against reentrancy attacks by acquiring a lock before
    /// function execution and releasing it afterward.
    modifier lock() {
        _acquireLock();
        _;
        _releaseLock();
    }

    /// @dev Guards against read-only reentrancy attacks by ensuring no write
    /// lock is currently held.
    modifier whenUnlocked() {
        _assertUnlocked();
        _;
    }

    // =========================================================================
    // Functions - Internal
    // =========================================================================

    /// @notice Acquires the lock. Once acquired, no reentrant calls can be made
    /// to functions that use the `lock` or `whenUnlocked` modifiers.
    function _acquireLock() internal virtual {
        assembly ("memory-safe") {
            if tload(MUTEX_TRANSIENT_SLOT) {
                mstore(0x00, 0x02c73c37) // `Mutex__Locked()`
                revert(0x1c, 0x04)
            }

            tstore(MUTEX_TRANSIENT_SLOT, 1)
        }
    }

    /// @notice Releases the lock.
    function _releaseLock() internal virtual {
        assembly ("memory-safe") {
            tstore(MUTEX_TRANSIENT_SLOT, 0)
        }
    }

    /// @notice Returns whether the lock is currently held.
    ///
    /// @return result True if locked, false otherwise.
    function _isLocked() internal view virtual returns (bool result) {
        assembly ("memory-safe") {
            result := iszero(iszero(tload(MUTEX_TRANSIENT_SLOT)))
        }
    }

    /// @notice Asserts that the lock is not currently held.
    function _assertUnlocked() internal view virtual {
        assembly ("memory-safe") {
            if tload(MUTEX_TRANSIENT_SLOT) {
                mstore(0x00, 0x02c73c37) // `Mutex__Locked()`
                revert(0x1c, 0x04)
            }
        }
    }
}
