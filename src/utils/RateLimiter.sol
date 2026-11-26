// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { IRateLimiter } from "./IRateLimiter.sol";

/// @title RateLimiter
///
/// @author TSxo
///
/// @notice Caps how much can be consumed per unit of time, using token buckets.
///
/// @dev Each bucket, identified by a `bytes32` id, holds up to `capacity` units
/// and refills at `rate` units per second. `_consume` takes units from a bucket
/// and reverts if it does not hold enough. Over any interval of `t` seconds,
/// cumulative consumption cannot exceed `capacity + rate * t`.
///
/// Typical uses are capping outflows of a token, per user, per direction, or in
/// total, so that an exploit or a compromised key can only drain so much before
/// someone reacts. Choose ids to suit, for example
/// `keccak256(abi.encode(token, "withdraw"))`.
///
/// # Behavior
///
/// - A new bucket starts full.
/// - An unconfigured bucket has no capacity, so it rejects any non-zero amount.
/// - Changing a limit first refills the bucket under its old settings, so the
///   new rate applies only from the change onwards, and then caps it at the new
///   capacity.
/// - Amounts are in whatever unit the integrator chooses, such as token wei.
///
/// # Arithmetic
///
/// The refill `tokens + elapsed * rate` cannot overflow 256 bits: `tokens` and
/// `rate` are below 2^128 and `elapsed` below 2^64, so the sum stays below
/// 2^193. It is therefore computed unchecked.
///
/// # Upgrade Compatible
///
/// This contract uses ERC-7201 namespaced storage, making it compatible with
/// upgradeable contract architectures.
abstract contract RateLimiter is IRateLimiter {
    // =========================================================================
    // Type Declarations
    // =========================================================================

    /// @dev Packed into two slots: `capacity` (bits 0-127) and `rate` (bits
    /// 128-255), then `tokens` (bits 0-127) and `updatedAt` (bits 128-191).
    struct Bucket {
        uint128 capacity;
        uint128 rate;
        uint128 tokens;
        uint64 updatedAt;
    }

    /// @custom:storage-location erc7201:libsol.storage.RateLimiter
    struct RateLimiterStorage {
        mapping(bytes32 id => Bucket) buckets;
    }

    // =========================================================================
    // Constants
    // =========================================================================

    /// @dev keccak256(abi.encode(uint256(keccak256("libsol.storage.RateLimiter")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant RATE_LIMITER_SLOT = 0x59a03ba974831f58934bc63224f471cf529f3ec5e5199b1d40a72068d7024200;

    /// @dev keccak256(bytes("RateLimitUpdated(bytes32,uint256,uint256)"))
    bytes32 private constant RATE_LIMIT_UPDATED = 0x0ae80bf6c6ab41f12ede33d03ecb3d158518f3ce6e124cc5cc534476226fcd7f;

    /// @dev Mask for a 128-bit field.
    uint256 private constant MASK_128 = 0xffffffffffffffffffffffffffffffff;

    /// @dev Mask for a 64-bit field.
    uint256 private constant MASK_64 = 0xffffffffffffffff;

    // =========================================================================
    // Functions - Public
    // =========================================================================

    /// @inheritdoc IRateLimiter
    function rateLimit(bytes32 id) public view virtual returns (uint256 capacity, uint256 rate) {
        assembly ("memory-safe") {
            mstore(0x00, id)
            mstore(0x20, RATE_LIMITER_SLOT)
            let settings := sload(keccak256(0x00, 0x40))

            // settings = capacity | rate << 128
            capacity := and(settings, MASK_128)
            rate := shr(128, settings)
        }
    }

    /// @inheritdoc IRateLimiter
    function availableCapacity(bytes32 id) public view virtual returns (uint256 result) {
        assembly ("memory-safe") {
            mstore(0x00, id)
            mstore(0x20, RATE_LIMITER_SLOT)
            let slot := keccak256(0x00, 0x40)

            // settings = capacity | rate << 128
            // state    = tokens | updatedAt << 128
            let settings := sload(slot)
            let state := sload(add(slot, 1))

            let capacity := and(settings, MASK_128)

            // elapsed = now - updatedAt
            let elapsed := sub(timestamp(), and(shr(128, state), MASK_64))

            // refilled = tokens + elapsed * rate
            let refilled := add(and(state, MASK_128), mul(elapsed, shr(128, settings)))

            // result = min(refilled, capacity)
            result := capacity
            if lt(refilled, capacity) { result := refilled }
        }
    }

    // =========================================================================
    // Functions - Internal
    // =========================================================================

    /// @notice Sets or changes a bucket's limit.
    ///
    /// @param id       The bucket.
    /// @param capacity The most the bucket can hold.
    /// @param rate     Refill per second; zero for a budget that never refills.
    ///
    /// @dev Internal function with no access control.
    ///
    /// Emits a `RateLimitUpdated` event.
    function _setRateLimit(bytes32 id, uint128 capacity, uint128 rate) internal virtual {
        assembly ("memory-safe") {
            capacity := and(capacity, MASK_128)
            rate := and(rate, MASK_128)

            mstore(0x00, id)
            mstore(0x20, RATE_LIMITER_SLOT)
            let slot := keccak256(0x00, 0x40)

            // A new bucket starts full. An existing one is refilled under its
            // old settings first, then capped at the new capacity.
            let tokens := capacity

            // state = tokens | updatedAt << 128
            let state := sload(add(slot, 1))
            let updatedAt := and(shr(128, state), MASK_64)

            // A bucket has been configured once `updatedAt` is set.
            if updatedAt {
                // settings = oldCapacity | oldRate << 128
                let settings := sload(slot)

                // available = tokens + (now - updatedAt) * oldRate
                let available := add(and(state, MASK_128), mul(sub(timestamp(), updatedAt), shr(128, settings)))

                // tokens = min(available, oldCapacity, capacity)
                let oldCapacity := and(settings, MASK_128)
                if gt(available, oldCapacity) { available := oldCapacity }
                if lt(available, tokens) { tokens := available }
            }

            // settings = capacity | rate << 128
            sstore(slot, or(capacity, shl(128, rate)))

            // state = tokens | now << 128
            sstore(add(slot, 1), or(tokens, shl(128, timestamp())))

            mstore(0x00, capacity)
            mstore(0x20, rate)
            log2(0x00, 0x40, RATE_LIMIT_UPDATED, id)
        }
    }

    /// @notice Takes `amount` from a bucket.
    ///
    /// @param id     The bucket.
    /// @param amount The amount to take.
    ///
    /// @dev Requirements:
    /// - The bucket must hold at least `amount` after refilling.
    function _consume(bytes32 id, uint256 amount) internal virtual {
        assembly ("memory-safe") {
            // Nothing to take, and writing would mark an unconfigured bucket as
            // configured.
            if amount {
                mstore(0x00, id)
                mstore(0x20, RATE_LIMITER_SLOT)
                let slot := keccak256(0x00, 0x40)

                // settings = capacity | rate << 128
                // state    = tokens | updatedAt << 128
                let settings := sload(slot)
                let state := sload(add(slot, 1))

                let capacity := and(settings, MASK_128)

                // elapsed = now - updatedAt
                let elapsed := sub(timestamp(), and(shr(128, state), MASK_64))

                // available = min(tokens + elapsed * rate, capacity)
                let available := add(and(state, MASK_128), mul(elapsed, shr(128, settings)))
                if gt(available, capacity) { available := capacity }

                if gt(amount, available) {
                    mstore(0x00, 0xf66fb841) // `RateLimiter__Exceeded()`
                    revert(0x1c, 0x04)
                }

                // state = (available - amount) | now << 128
                sstore(add(slot, 1), or(sub(available, amount), shl(128, timestamp())))
            }
        }
    }
}
