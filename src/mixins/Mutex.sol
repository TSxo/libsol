// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/// @title Mutex
///
/// @author TSxo
///
/// @dev Provides mechanisms to guard against reentrancy attacks.
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
/// private functions and compose calls to them from a single guarded entry point.
///
/// For the rationale behind `1` and `2` representing locked states, see:
/// - https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/ReentrancyGuard.sol
/// - https://eips.ethereum.org/EIPS/eip-2200
///
/// # Upgrade Compatible
///
/// This contract utilizes ERC-7201 namespaced storage, making it compatible with
/// upgradeable contract architectures. Note, it does not enforce any restrictions
/// against reinitialization, leaving such protection mechanisms up to the
/// inheriting contract.
///
/// # Acknowledgements
///
/// Heavy inspiration is taken from:
/// - OpenZeppelin;
/// - Solmate; and
/// - Solady.
///
/// Thank you.
abstract contract Mutex {
    // -------------------------------------------------------------------------
    // Type Declarations

    /// @custom:storage-location erc7201:libsol.storage.Mutex
    struct MutexStorage {
        uint256 locked;
    }

    // -------------------------------------------------------------------------
    // State

    /// @dev keccak256(abi.encode(uint256(keccak256("libsol.storage.Mutex")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MUTEX_SLOT = 0x4772547a0c85096864cfb8fb79e76bca1fc87ca09848b27c5507e4697fcfd100;

    /// @dev Represents the unlocked state.
    uint256 private constant UNLOCKED = 1;

    /// @dev Represents the locked state.
    uint256 private constant LOCKED = 2;

    // -------------------------------------------------------------------------
    // Errors

    /// @notice Raised when entering a guarded function after a lock has been
    /// acquired.
    error Mutex__Locked();

    // -------------------------------------------------------------------------
    // Modifiers

    /// @dev Guards against reentrancy attacks by acquiring a lock before function
    /// execution and releasing it afterward.
    modifier lock() virtual {
        _acquireLock();
        _;
        _releaseLock();
    }

    /// @dev Guards against read-only reentrancy attacks by ensuring no write
    /// lock is held.
    ///
    /// Important: Does not acquire a lock. See the `lock()` modifier.
    modifier whenUnlocked() virtual {
        _assertUnlocked();
        _;
    }

    // -------------------------------------------------------------------------
    // Functions - Init

    /// @notice Initializes the contract by setting the locked status to `UNLOCKED`.
    function _initializeMutex() internal virtual {
        assembly ("memory-safe") {
            sstore(MUTEX_SLOT, UNLOCKED)
        }
    }

    // -------------------------------------------------------------------------
    // Functions - Internal

    /// @notice Acquires the lock. Once acquired, no reentrant calls can be made
    /// to functions that use the `lock` or `whenUnlocked` modifiers.
    function _acquireLock() internal virtual {
        _assertUnlocked();

        assembly ("memory-safe") {
            sstore(MUTEX_SLOT, LOCKED)
        }
    }

    /// @notice Releases the lock.
    function _releaseLock() internal virtual {
        assembly ("memory-safe") {
            sstore(MUTEX_SLOT, UNLOCKED)
        }
    }

    /// @notice Returns whether the lock is currently acquired.
    ///
    /// @return result True if the lock is acquired, false otherwise.
    function _isLocked() internal view virtual returns (bool result) {
        assembly ("memory-safe") {
            result := eq(sload(MUTEX_SLOT), LOCKED)
        }
    }

    /// @notice Asserts that the lock has not been acquired.
    function _assertUnlocked() internal view virtual {
        assembly ("memory-safe") {
            if eq(sload(MUTEX_SLOT), LOCKED) {
                mstore(0x00, 0x02c73c37) // `Mutex__Locked()`
                revert(0x1c, 0x04)
            }
        }
    }
}
