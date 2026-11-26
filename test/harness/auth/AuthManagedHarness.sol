// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Brutalizer } from "lib/solady/test/utils/Brutalizer.sol";

import { AuthManaged } from "@tsxo/libsol/auth/managed/AuthManaged.sol";

/// @notice `AuthManaged` with two restricted functions.
///
/// @dev Brutalizing harness: every function of the module under test that takes
/// an address, bool, narrow integer, or `bytes4` is overridden to pass its
/// arguments on with dirty unused bits (Solady's `Brutalizer`). Entry points,
/// and the internal functions whose assembly allocates or reads back memory,
/// also fill memory with junk first and check it afterwards. Every test that
/// uses this harness therefore runs with dirty inputs, which only reach
/// assembly through an internal call like this one: the ABI decoder rejects
/// them in calldata.
contract AuthManagedHarness is AuthManaged, Brutalizer {
    uint256 public count;

    constructor(address initialAuthority) {
        _initializeAuthManaged(initialAuthority);
    }

    function increment() external auth {
        count++;
    }

    function decrement() external auth {
        count--;
    }

    // =========================================================================
    // Brutalized - Public
    // =========================================================================

    function setAuthority(address newAuthority) public override {
        _brutalizeMemory();
        super.setAuthority(_brutalized(newAuthority));
        _checkMemory();
    }

    // =========================================================================
    // Brutalized - Internal
    // =========================================================================

    function _initializeAuthManaged(address initialAuthority) internal override {
        super._initializeAuthManaged(_brutalized(initialAuthority));
    }

    function _setAuthority(address newAuthority) internal override {
        super._setAuthority(_brutalized(newAuthority));
    }

    /// @dev Builds the `canCall` query in free memory and reads the reply from
    /// scratch space, so memory is brutalized and checked here, under every
    /// `auth` function.
    function _assertAuthorized(address user, bytes4 selector) internal view override {
        _brutalizeMemory();
        super._assertAuthorized(_brutalized(user), _brutalizedBytes4(selector));
        _checkMemory();
    }
}
