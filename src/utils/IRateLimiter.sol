// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/// @title IRateLimiter
///
/// @author TSxo
///
/// @notice Interface for the `RateLimiter` contract.
interface IRateLimiter {
    // =========================================================================
    // Events
    // =========================================================================

    /// @notice Emitted when a bucket's limit is set or changed.
    ///
    /// @param id       The bucket.
    /// @param capacity The most the bucket can hold.
    /// @param rate     How much the bucket refills per second.
    event RateLimitUpdated(bytes32 indexed id, uint256 capacity, uint256 rate);

    // =========================================================================
    // Errors
    // =========================================================================

    /// @notice The amount is more than the bucket currently holds.
    error RateLimiter__Exceeded();

    // =========================================================================
    // Functions
    // =========================================================================

    /// @notice Returns a bucket's limit.
    ///
    /// @param id The bucket.
    ///
    /// @return capacity The most the bucket can hold.
    /// @return rate     How much the bucket refills per second.
    function rateLimit(bytes32 id) external view returns (uint256 capacity, uint256 rate);

    /// @notice Returns how much can be consumed from a bucket right now.
    ///
    /// @param id The bucket.
    ///
    /// @return result The amount available now, including any refill.
    function availableCapacity(bytes32 id) external view returns (uint256 result);
}
