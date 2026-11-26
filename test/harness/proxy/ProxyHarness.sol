// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Brutalizer } from "lib/solady/test/utils/Brutalizer.sol";

import { Proxy } from "@tsxo/libsol/proxy/Proxy.sol";

/// @notice A `Proxy` that always delegates to one target.
///
/// @dev Brutalizing harness: every function of the module under test that takes
/// an address, bool, narrow integer, or `bytes4` is overridden to pass its
/// arguments on with dirty unused bits (Solady's `Brutalizer`). Entry points,
/// and the internal functions whose assembly allocates or reads back memory,
/// also fill memory with junk first and check it afterwards. Every test that
/// uses this harness therefore runs with dirty inputs, which only reach
/// assembly through an internal call like this one: the ABI decoder rejects
/// them in calldata.
contract ProxyHarness is Proxy, Brutalizer {
    address immutable _target;

    constructor(address target) {
        _target = target;
    }

    function _implementation() internal view override returns (address result) {
        return _target;
    }

    // =========================================================================
    // Brutalized - Internal
    // =========================================================================

    /// @dev Copies calldata and return data through free memory. It always
    /// returns or reverts, so memory is brutalized first but cannot be checked
    /// afterwards.
    function _delegate(address implementation) internal override {
        _brutalizeMemory();
        super._delegate(_brutalized(implementation));
    }
}
