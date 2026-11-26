// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";

import { IRateLimiter } from "@tsxo/libsol/utils/IRateLimiter.sol";

import { RateLimiterHarness } from "test/harness/utils/RateLimiterHarness.sol";

/// @notice Consumes from two buckets with different limits while Forge moves
/// time forward between calls (`max_time_delay`).
///
/// Each action checks what must hold around a single call: capacity never
/// shrinks while time passes, a consumption removes exactly what it asked for
/// and nothing from the other bucket, and asking for more than is available
/// always reverts. The ghosts record what each bucket released, for the
/// test's cumulative limit.
contract RateLimiterHandler is Test {
    RateLimiterHarness public immutable limiter;
    bytes32[2] public ids;

    mapping(bytes32 id => uint256) public ghost_totalConsumed;

    /// @dev Each bucket's capacity after the last action that touched it.
    mapping(bytes32 id => uint256) public ghost_availableAfter;

    constructor(RateLimiterHarness limiter_, bytes32[2] memory ids_) {
        limiter = limiter_;
        ids = ids_;
        for (uint256 i; i < ids_.length; ++i) {
            ghost_availableAfter[ids_[i]] = limiter_.availableCapacity(ids_[i]);
        }
    }

    // =========================================================================
    // Actions
    // =========================================================================

    /// @dev Consumes up to what is available, which must succeed.
    function consume(bool secondBucket, uint256 amount) external {
        (bytes32 id, bytes32 other) = _pair(secondBucket);
        uint256 available = _availableAfterWait(id);
        uint256 otherBefore = limiter.availableCapacity(other);

        amount = bound(amount, 0, available);
        limiter.exposed_consume(id, amount);

        assertEq(limiter.availableCapacity(id), available - amount, "consumes exactly the amount");
        assertEq(limiter.availableCapacity(other), otherBefore, "other bucket untouched");

        ghost_totalConsumed[id] += amount;
        ghost_availableAfter[id] = available - amount;
    }

    /// @dev Asks for more than is available, which must revert and change
    /// nothing.
    function overconsume(bool secondBucket, uint256 excess) external {
        (bytes32 id,) = _pair(secondBucket);
        uint256 available = _availableAfterWait(id);

        excess = bound(excess, 1, type(uint128).max);
        vm.expectRevert(IRateLimiter.RateLimiter__Exceeded.selector);
        limiter.exposed_consume(id, available + excess);

        assertEq(limiter.availableCapacity(id), available, "failed consumption changes nothing");
        ghost_availableAfter[id] = available;
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    function _pair(bool secondBucket) internal view returns (bytes32 id, bytes32 other) {
        (id, other) = secondBucket ? (ids[1], ids[0]) : (ids[0], ids[1]);
    }

    /// @dev Reads what `id` holds now, after Forge's time delay, and checks
    /// the wait did not lose any of what it held after its last action.
    function _availableAfterWait(bytes32 id) internal view returns (uint256 available) {
        available = limiter.availableCapacity(id);
        assertGe(available, ghost_availableAfter[id], "waiting never loses capacity");
    }
}
