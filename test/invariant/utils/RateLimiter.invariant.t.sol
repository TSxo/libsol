// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";

import { RateLimiterHarness } from "test/harness/utils/RateLimiterHarness.sol";
import { RateLimiterHandler } from "test/invariant/utils/handlers/RateLimiterHandler.sol";

/// @notice The guarantee a rate limiter exists to give: whatever the sequence
/// of consumption and elapsed time, a bucket never releases more than its
/// capacity plus what it has refilled, and never holds more than its capacity.
/// Two buckets with different limits run side by side.
///
/// Forge advances time by up to a day before each call.
/// forge-config: default.invariant.max_time_delay = 86400
/// forge-config: ci.invariant.max_time_delay = 86400
contract RateLimiterInvariantTest is Test {
    bytes32 constant WITHDRAWALS = keccak256("withdrawals");
    bytes32 constant DEPOSITS = keccak256("deposits");

    /// @dev Withdrawals refill a full bucket in about 11.6 days; deposits, with
    /// a small capacity and a fast rate, in 100 seconds.
    uint128 constant WITHDRAWAL_CAPACITY = 1_000e18;
    uint128 constant WITHDRAWAL_RATE = 1e15;
    uint128 constant DEPOSIT_CAPACITY = 100e18;
    uint128 constant DEPOSIT_RATE = 1e18;

    RateLimiterHarness limiter;
    RateLimiterHandler handler;
    uint256 startedAt;

    function setUp() public {
        limiter = new RateLimiterHarness();
        limiter.exposed_setRateLimit(WITHDRAWALS, WITHDRAWAL_CAPACITY, WITHDRAWAL_RATE);
        limiter.exposed_setRateLimit(DEPOSITS, DEPOSIT_CAPACITY, DEPOSIT_RATE);
        startedAt = vm.getBlockTimestamp();

        handler = new RateLimiterHandler(limiter, [WITHDRAWALS, DEPOSITS]);
        targetContract(address(handler));
    }

    /// @dev Bounds: the total released never exceeds the starting capacity
    /// plus everything refilled since.
    function invariant_TotalConsumed_StaysWithinLimit() public view {
        uint256 elapsed = vm.getBlockTimestamp() - startedAt;

        assertLe(handler.ghost_totalConsumed(WITHDRAWALS), WITHDRAWAL_CAPACITY + elapsed * WITHDRAWAL_RATE);
        assertLe(handler.ghost_totalConsumed(DEPOSITS), DEPOSIT_CAPACITY + elapsed * DEPOSIT_RATE);
    }

    /// @dev Bounds: refilling stops at capacity.
    function invariant_Available_NeverExceedsCapacity() public view {
        assertLe(limiter.availableCapacity(WITHDRAWALS), WITHDRAWAL_CAPACITY);
        assertLe(limiter.availableCapacity(DEPOSITS), DEPOSIT_CAPACITY);
    }

    /// @dev State consistency: the limits themselves never change.
    function invariant_Limits_Unchanged() public view {
        (uint256 capacity, uint256 rate) = limiter.rateLimit(WITHDRAWALS);
        assertEq(capacity, WITHDRAWAL_CAPACITY);
        assertEq(rate, WITHDRAWAL_RATE);

        (capacity, rate) = limiter.rateLimit(DEPOSITS);
        assertEq(capacity, DEPOSIT_CAPACITY);
        assertEq(rate, DEPOSIT_RATE);
    }
}
