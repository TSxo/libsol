// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Brutalizer } from "lib/solady/test/utils/Brutalizer.sol";

import { Owned } from "@tsxo/libsol/auth/Owned.sol";

/// @notice `Owned` with one owner-only function.
///
/// @dev Brutalizing harness: every function of the module under test that takes
/// an address, bool, narrow integer, or `bytes4` is overridden to pass its
/// arguments on with dirty unused bits (Solady's `Brutalizer`). Entry points,
/// and the internal functions whose assembly allocates or reads back memory,
/// also fill memory with junk first and check it afterwards. Every test that
/// uses this harness therefore runs with dirty inputs, which only reach
/// assembly through an internal call like this one: the ABI decoder rejects
/// them in calldata.
contract OwnedHarness is Owned, Brutalizer {
    uint256 public count;

    constructor(address initialOwner) {
        _initializeOwned(initialOwner);
    }

    function setCount(uint256 n) external onlyOwner {
        count = n;
    }

    // =========================================================================
    // Brutalized - Public
    // =========================================================================

    function transferOwnership(address newOwner) public override {
        _brutalizeMemory();
        super.transferOwnership(_brutalized(newOwner));
        _checkMemory();
    }

    // =========================================================================
    // Brutalized - Internal
    // =========================================================================

    function _initializeOwned(address initialOwner) internal override {
        super._initializeOwned(_brutalized(initialOwner));
    }

    function _transferOwnership(address newOwner) internal override {
        super._transferOwnership(_brutalized(newOwner));
    }
}
