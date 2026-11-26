// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Brutalizer } from "lib/solady/test/utils/Brutalizer.sol";

import { Pausable } from "@tsxo/libsol/pause/Pausable.sol";

/// @notice `Pausable` with functions gated each way, and its setter exposed.
///
/// @dev Brutalizing harness: every function of the module under test that takes
/// an address, bool, narrow integer, or `bytes4` is overridden to pass its
/// arguments on with dirty unused bits (Solady's `Brutalizer`). Entry points,
/// and the internal functions whose assembly allocates or reads back memory,
/// also fill memory with junk first and check it afterwards. Every test that
/// uses this harness therefore runs with dirty inputs, which only reach
/// assembly through an internal call like this one: the ABI decoder rejects
/// them in calldata.
contract PausableHarness is Pausable, Brutalizer {
    uint256 public count;

    function incrementWhenNotPaused() external notPaused {
        count++;
    }

    function incrementWhenPaused() external paused {
        count++;
    }

    function exposed_setPaused(bool enabled) external {
        _brutalizeMemory();
        _setPaused(enabled);
        _checkMemory();
    }

    /// @dev Compiles only because the modifiers' asserts are `view`.
    function countWhenNotPaused() external view notPaused returns (uint256) {
        return count;
    }

    function countWhenPaused() external view paused returns (uint256) {
        return count;
    }

    // =========================================================================
    // Brutalized - Internal
    // =========================================================================

    function _setPaused(bool enabled) internal override {
        super._setPaused(_brutalized(enabled));
    }
}
