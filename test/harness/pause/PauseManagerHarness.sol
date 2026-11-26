// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Brutalizer } from "lib/solady/test/utils/Brutalizer.sol";

import { PauseManager } from "@tsxo/libsol/pause/managed/PauseManager.sol";
import { Owned } from "@tsxo/libsol/auth/Owned.sol";

/// @notice `PauseManager`, managed by an owner.
///
/// @dev Brutalizing harness: every function of the module under test that takes
/// an address, bool, narrow integer, or `bytes4` is overridden to pass its
/// arguments on with dirty unused bits (Solady's `Brutalizer`). Entry points,
/// and the internal functions whose assembly allocates or reads back memory,
/// also fill memory with junk first and check it afterwards. Every test that
/// uses this harness therefore runs with dirty inputs, which only reach
/// assembly through an internal call like this one: the ABI decoder rejects
/// them in calldata.
contract PauseManagerHarness is Owned, PauseManager, Brutalizer {
    constructor(address initialOwner) {
        _initializeOwned(initialOwner);
    }

    function _authorizeManager() internal view override onlyOwner { }

    // =========================================================================
    // Brutalized - Public
    // =========================================================================

    function setTargetPaused(address target, bool enabled) public override {
        _brutalizeMemory();
        super.setTargetPaused(_brutalized(target), _brutalized(enabled));
        _checkMemory();
    }

    function setGloballyPaused(bool enabled) public override {
        _brutalizeMemory();
        super.setGloballyPaused(_brutalized(enabled));
        _checkMemory();
    }

    function setPauseAuthority(address target, address newAuthority) public override {
        _brutalizeMemory();
        super.setPauseAuthority(_brutalized(target), _brutalized(newAuthority));
        _checkMemory();
    }

    function isPaused(address target) public view override returns (bool result) {
        _brutalizeMemory();
        result = super.isPaused(_brutalized(target));
        _checkMemory();
    }

    function isTargetPaused(address target) public view override returns (bool result) {
        _brutalizeMemory();
        result = super.isTargetPaused(_brutalized(target));
        _checkMemory();
    }

    // =========================================================================
    // Brutalized - Internal
    // =========================================================================

    function _setTargetPaused(address target, bool enabled) internal override {
        super._setTargetPaused(_brutalized(target), _brutalized(enabled));
    }

    function _setGloballyPaused(bool enabled) internal override {
        super._setGloballyPaused(_brutalized(enabled));
    }
}
