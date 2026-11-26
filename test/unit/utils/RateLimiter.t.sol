// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";

import { IRateLimiter } from "@tsxo/libsol/utils/IRateLimiter.sol";

import { RateLimiterHarness } from "test/harness/utils/RateLimiterHarness.sol";

interface TestEvents {
    event RateLimitUpdated(bytes32 indexed id, uint256 capacity, uint256 rate);
}

contract RateLimiterTest is Test, TestEvents {
    bytes32 constant ID = keccak256("withdrawals");
    uint128 constant CAPACITY = 1000;
    uint128 constant RATE = 10; // per second

    RateLimiterHarness limiter;

    function setUp() public {
        limiter = new RateLimiterHarness();
    }

    // =========================================================================
    // Test - Configuration
    // =========================================================================

    function test_NewBucket_StartsFull() public {
        vm.expectEmit(address(limiter));
        emit RateLimitUpdated(ID, CAPACITY, RATE);
        limiter.exposed_setRateLimit(ID, CAPACITY, RATE);

        (uint256 capacity, uint256 rate) = limiter.rateLimit(ID);
        assertEq(capacity, CAPACITY);
        assertEq(rate, RATE);
        assertEq(limiter.availableCapacity(ID), CAPACITY);
    }

    /// @dev Limits fail closed: an unconfigured bucket rejects any amount.
    function testFuzz_RevertWhen_Consume_BucketIsUnconfigured(uint256 amount) public {
        amount = bound(amount, 1, type(uint256).max);

        vm.expectRevert(IRateLimiter.RateLimiter__Exceeded.selector);
        limiter.exposed_consume(ID, amount);
    }

    /// @dev Consuming zero from an unconfigured bucket must not mark it as
    /// configured: once configured, it still starts full.
    function test_ZeroConsume_DoesNotConfigureBucket() public {
        limiter.exposed_consume(ID, 0);
        vm.warp(vm.getBlockTimestamp() + 1 days);

        limiter.exposed_setRateLimit(ID, CAPACITY, RATE);
        assertEq(limiter.availableCapacity(ID), CAPACITY);
    }

    function test_Buckets_AreIndependent() public {
        bytes32 other = keccak256("deposits");
        limiter.exposed_setRateLimit(ID, CAPACITY, RATE);
        limiter.exposed_setRateLimit(other, CAPACITY, RATE);

        limiter.exposed_consume(ID, CAPACITY);

        assertEq(limiter.availableCapacity(ID), 0);
        assertEq(limiter.availableCapacity(other), CAPACITY);
    }

    // =========================================================================
    // Test - Consume
    // =========================================================================

    function test_Consume_TakesFromBucket() public {
        limiter.exposed_setRateLimit(ID, CAPACITY, RATE);

        limiter.exposed_consume(ID, 400);
        assertEq(limiter.availableCapacity(ID), 600);

        // Exactly what is left is allowed; one more is not.
        limiter.exposed_consume(ID, 600);
        vm.expectRevert(IRateLimiter.RateLimiter__Exceeded.selector);
        limiter.exposed_consume(ID, 1);
    }

    function test_Bucket_RefillsAtRateUpToCapacity() public {
        limiter.exposed_setRateLimit(ID, CAPACITY, RATE);
        limiter.exposed_consume(ID, CAPACITY);

        vm.warp(vm.getBlockTimestamp() + 30);
        assertEq(limiter.availableCapacity(ID), 300);

        vm.warp(vm.getBlockTimestamp() + 1 days);
        assertEq(limiter.availableCapacity(ID), CAPACITY);
    }

    /// @dev Zero rate is a fixed budget that never refills.
    function test_ZeroRate_NeverRefills() public {
        limiter.exposed_setRateLimit(ID, CAPACITY, 0);
        limiter.exposed_consume(ID, CAPACITY);

        vm.warp(vm.getBlockTimestamp() + 365 days);
        assertEq(limiter.availableCapacity(ID), 0);
    }

    function testFuzz_Available_MatchesFormula(uint128 capacity, uint128 rate, uint256 spent, uint32 elapsed) public {
        spent = bound(spent, 0, capacity);
        limiter.exposed_setRateLimit(ID, capacity, rate);
        limiter.exposed_consume(ID, spent);

        vm.warp(vm.getBlockTimestamp() + elapsed);

        uint256 refilled = uint256(capacity) - spent + uint256(elapsed) * rate;
        uint256 expected = refilled < capacity ? refilled : capacity;
        assertEq(limiter.availableCapacity(ID), expected);
    }

    // =========================================================================
    // Test - Reconfiguration
    // =========================================================================

    /// @dev The old rate applies up to the change, the new rate after it.
    function test_Reconfigure_RefillsUnderOldRateFirst() public {
        limiter.exposed_setRateLimit(ID, CAPACITY, RATE);
        limiter.exposed_consume(ID, CAPACITY);

        vm.warp(vm.getBlockTimestamp() + 10); // +100 at the old rate
        limiter.exposed_setRateLimit(ID, CAPACITY, RATE * 5);
        assertEq(limiter.availableCapacity(ID), 100);

        vm.warp(vm.getBlockTimestamp() + 10); // +500 at the new rate
        assertEq(limiter.availableCapacity(ID), 600);
    }

    function test_Reconfigure_LowerCapacityClampsTokens() public {
        limiter.exposed_setRateLimit(ID, CAPACITY, RATE);

        limiter.exposed_setRateLimit(ID, 300, RATE);
        assertEq(limiter.availableCapacity(ID), 300);
    }

    /// @dev Raising capacity does not hand out the difference at once.
    function test_Reconfigure_HigherCapacityKeepsTokens() public {
        limiter.exposed_setRateLimit(ID, CAPACITY, RATE);
        limiter.exposed_consume(ID, 500);

        limiter.exposed_setRateLimit(ID, CAPACITY * 2, RATE);
        assertEq(limiter.availableCapacity(ID), 500);
    }
}
