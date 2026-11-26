// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { RateLimiterReference } from "test/reference/utils/RateLimiterReference.sol";

contract RateLimiterReferenceHarness is RateLimiterReference {
    function exposed_setRateLimit(bytes32 id, uint128 capacity, uint128 rate) external {
        _setRateLimit(id, capacity, rate);
    }

    function exposed_consume(bytes32 id, uint256 amount) external {
        _consume(id, amount);
    }
}
