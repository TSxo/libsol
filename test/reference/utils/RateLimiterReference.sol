// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { IRateLimiter } from "@tsxo/libsol/utils/IRateLimiter.sol";

/// @title RateLimiterReference
///
/// @notice A plain-Solidity reference for `RateLimiter`, used to check the
/// assembly version in differential tests. Same behavior, events, and errors.
/// See `src/` for the documentation.
abstract contract RateLimiterReference is IRateLimiter {
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

    /// @dev keccak256(abi.encode(uint256(keccak256("libsol.storage.RateLimiter")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant RATE_LIMITER_SLOT = 0x59a03ba974831f58934bc63224f471cf529f3ec5e5199b1d40a72068d7024200;

    function rateLimit(bytes32 id) public view virtual returns (uint256 capacity, uint256 rate) {
        Bucket storage bucket = _getBucket(id);
        return (bucket.capacity, bucket.rate);
    }

    function availableCapacity(bytes32 id) public view virtual returns (uint256 result) {
        return _refilled(_getBucket(id));
    }

    function _setRateLimit(bytes32 id, uint128 capacity, uint128 rate) internal virtual {
        Bucket storage bucket = _getBucket(id);

        // A new bucket starts full. An existing one is refilled under its old
        // settings first, then capped at the new capacity.
        uint256 tokens = bucket.updatedAt == 0 ? capacity : _min(_refilled(bucket), capacity);

        bucket.capacity = capacity;
        bucket.rate = rate;

        // forge-lint: disable-next-line(unsafe-typecast) -- tokens <= capacity, a uint128.
        bucket.tokens = uint128(tokens);

        // forge-lint: disable-next-line(unsafe-typecast) -- timestamps fit in 64 bits.
        bucket.updatedAt = uint64(block.timestamp);

        // forge-lint: disable-next-line(reentrancy-events) -- no external call precedes it.
        emit RateLimitUpdated(id, capacity, rate);
    }

    function _consume(bytes32 id, uint256 amount) internal virtual {
        // Nothing to take, and writing would mark an unconfigured bucket as
        // configured.
        if (amount == 0) return;

        Bucket storage bucket = _getBucket(id);
        uint256 available = _refilled(bucket);

        if (amount > available) revert RateLimiter__Exceeded();

        // forge-lint: disable-next-line(unsafe-typecast) -- available <= capacity, a uint128.
        bucket.tokens = uint128(available - amount);

        // forge-lint: disable-next-line(unsafe-typecast) -- timestamps fit in 64 bits.
        bucket.updatedAt = uint64(block.timestamp);
    }

    /// @dev The bucket's contents after refilling up to now.
    function _refilled(Bucket storage bucket) private view returns (uint256) {
        uint256 elapsed = block.timestamp - bucket.updatedAt;
        return _min(bucket.tokens + elapsed * bucket.rate, bucket.capacity);
    }

    function _getBucket(bytes32 id) private view returns (Bucket storage) {
        RateLimiterStorage storage $;
        assembly ("memory-safe") {
            $.slot := RATE_LIMITER_SLOT
        }
        return $.buckets[id];
    }

    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}
