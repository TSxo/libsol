// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { RateLimiterHarness } from "test/harness/utils/RateLimiterHarness.sol";
import { RateLimiterReferenceHarness } from "test/harness/utils/RateLimiterReferenceHarness.sol";

import { DifferentialBase } from "../DifferentialBase.sol";

/// @notice The assembly `RateLimiter` matches the Solidity reference for any
/// sequence of limit changes, consumption, and elapsed time, across two
/// buckets.
///
/// This stands in for symbolic proofs, which time out on the refill's
/// multiplication of two unknowns.
contract RateLimiterDifferentialTest is DifferentialBase {
    enum Action {
        SetRateLimit,
        Consume
    }

    /// @dev One fuzzed step: wait, then act on one of the two buckets.
    ///
    /// For `SetRateLimit`, `capacity` and `rate` are bounded below 10,000 so
    /// that buckets run out, unless `huge` is set, which allows any 128-bit
    /// value. For `Consume`, `offset` asks for one less than is available,
    /// exactly what is available, or one more.
    struct Step {
        uint32 wait;
        uint8 action;
        bool secondBucket;
        uint128 capacity;
        uint128 rate;
        bool huge;
        uint8 offset;
    }

    bytes32[2] ids = [keccak256("withdrawals"), keccak256("deposits")];

    RateLimiterHarness actual;
    RateLimiterReferenceHarness expected;

    function setUp() public {
        actual = new RateLimiterHarness();
        expected = new RateLimiterReferenceHarness();
    }

    function testFuzz_AnySequence_MatchesReference(Step[STEPS] calldata steps) public {
        for (uint256 i; i < STEPS; ++i) {
            Step calldata step = steps[i];
            vm.warp(vm.getBlockTimestamp() + bound(step.wait, 0, 2 days));

            bytes32 id = ids[step.secondBucket ? 1 : 0];
            Action action = Action(bound(step.action, 0, uint256(type(Action).max)));

            bytes memory data = action == Action.SetRateLimit
                ? abi.encodeCall(
                    RateLimiterHarness.exposed_setRateLimit,
                    (id, _limit(step.capacity, step.huge), _limit(step.rate, step.huge))
                )
                : abi.encodeCall(
                    RateLimiterHarness.exposed_consume,
                    (id, _nearAvailable(expected.availableCapacity(id), step.offset))
                );

            _callBoth(address(actual), address(expected), address(this), data);

            for (uint256 j; j < ids.length; ++j) {
                assertEq(actual.availableCapacity(ids[j]), expected.availableCapacity(ids[j]), "available");

                (uint256 actualCapacity, uint256 actualRate) = actual.rateLimit(ids[j]);
                (uint256 expectedCapacity, uint256 expectedRate) = expected.rateLimit(ids[j]);
                assertEq(actualCapacity, expectedCapacity, "capacity");
                assertEq(actualRate, expectedRate, "rate");
            }
        }
    }

    /// @dev Below 10,000, or any 128-bit value if `huge`.
    function _limit(uint128 value, bool huge) internal pure returns (uint128) {
        return huge ? value : uint128(bound(value, 0, 9_999));
    }

    /// @dev One less than `available` (zero if none is), exactly `available`,
    /// or one more.
    function _nearAvailable(uint256 available, uint8 offset) internal pure returns (uint256) {
        uint256 o = bound(offset, 0, 2);
        if (o == 0) return available == 0 ? 0 : available - 1;
        if (o == 1) return available;
        return available + 1;
    }
}
