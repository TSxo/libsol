// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Brutalizer } from "lib/solady/test/utils/Brutalizer.sol";

import { RateLimiter } from "@tsxo/libsol/utils/RateLimiter.sol";

/// @notice `RateLimiter` with its internal functions exposed.
///
/// @dev Brutalizing harness: every function of the module under test that takes
/// an address, bool, narrow integer, or `bytes4` is overridden to pass its
/// arguments on with dirty unused bits (Solady's `Brutalizer`). Entry points,
/// and the internal functions whose assembly allocates or reads back memory,
/// also fill memory with junk first and check it afterwards. Every test that
/// uses this harness therefore runs with dirty inputs, which only reach
/// assembly through an internal call like this one: the ABI decoder rejects
/// them in calldata.
contract RateLimiterHarness is RateLimiter, Brutalizer {
    function exposed_setRateLimit(bytes32 id, uint128 capacity, uint128 rate) external {
        _brutalizeMemory();
        _setRateLimit(id, capacity, rate);
        _checkMemory();
    }

    function exposed_consume(bytes32 id, uint256 amount) external {
        _brutalizeMemory();
        _consume(id, amount);
        _checkMemory();
    }

    // =========================================================================
    // Brutalized - Internal
    // =========================================================================

    function _setRateLimit(bytes32 id, uint128 capacity, uint128 rate) internal override {
        super._setRateLimit(id, _brutalizedUint128(capacity), _brutalizedUint128(rate));
    }
}
