// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Brutalizer } from "lib/solady/test/utils/Brutalizer.sol";

import { UpgradeableBeacon } from "@tsxo/libsol/proxy/beacon/UpgradeableBeacon.sol";

/// @notice `UpgradeableBeacon`, unchanged apart from brutalization.
///
/// @dev Brutalizing harness: every function of the module under test that takes
/// an address, bool, narrow integer, or `bytes4` is overridden to pass its
/// arguments on with dirty unused bits (Solady's `Brutalizer`). Entry points,
/// and the internal functions whose assembly allocates or reads back memory,
/// also fill memory with junk first and check it afterwards. Every test that
/// uses this harness therefore runs with dirty inputs, which only reach
/// assembly through an internal call like this one: the ABI decoder rejects
/// them in calldata.
///
/// The constructor's initial implementation goes through `_setImplementation`
/// too, so it is dirtied as well. `_setImplementation` touches no memory beyond
/// its revert, so it needs no memory brutalization of its own.
contract UpgradeableBeaconHarness is UpgradeableBeacon, Brutalizer {
    constructor(address initialOwner, address initialImplementation)
        UpgradeableBeacon(initialOwner, initialImplementation)
    { }

    // =========================================================================
    // Brutalized - Public
    // =========================================================================

    function upgradeTo(address newImplementation) public override {
        _brutalizeMemory();
        super.upgradeTo(_brutalized(newImplementation));
        _checkMemory();
    }

    // =========================================================================
    // Brutalized - Internal
    // =========================================================================

    function _setImplementation(address newImplementation) internal override {
        super._setImplementation(_brutalized(newImplementation));
    }
}
