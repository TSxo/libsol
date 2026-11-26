// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Brutalizer } from "lib/solady/test/utils/Brutalizer.sol";

import { PauseManaged } from "@tsxo/libsol/pause/managed/PauseManaged.sol";

/// @notice `PauseManaged` with functions gated by its pause authority.
///
/// @dev Brutalizing harness: every function of the module under test that takes
/// an address, bool, narrow integer, or `bytes4` is overridden to pass its
/// arguments on with dirty unused bits (Solady's `Brutalizer`). Entry points,
/// and the internal functions whose assembly allocates or reads back memory,
/// also fill memory with junk first and check it afterwards. Every test that
/// uses this harness therefore runs with dirty inputs, which only reach
/// assembly through an internal call like this one: the ABI decoder rejects
/// them in calldata.
contract PauseManagedHarness is PauseManaged, Brutalizer {
    uint256 public count;

    constructor(address initialAuthority) {
        _initializePauseManaged(initialAuthority);
    }

    function increment() external notPaused {
        count++;
    }

    function decrement() external notPaused {
        count--;
    }

    /// @dev Compiles only because `_assertNotPaused` is `view`.
    function countWhenNotPaused() external view notPaused returns (uint256) {
        return count;
    }

    // =========================================================================
    // Brutalized - Public
    // =========================================================================

    function setPauseAuthority(address newAuthority) public override {
        _brutalizeMemory();
        super.setPauseAuthority(_brutalized(newAuthority));
        _checkMemory();
    }

    // =========================================================================
    // Brutalized - Internal
    // =========================================================================

    function _initializePauseManaged(address initialAuthority) internal override {
        super._initializePauseManaged(_brutalized(initialAuthority));
    }

    function _setPauseAuthority(address newAuthority) internal override {
        super._setPauseAuthority(_brutalized(newAuthority));
    }

    /// @dev Takes no arguments, but reads the authority's reply from scratch
    /// space, so memory is brutalized and checked here, under every
    /// `notPaused` function.
    function _assertNotPaused() internal view override {
        _brutalizeMemory();
        super._assertNotPaused();
        _checkMemory();
    }
}
