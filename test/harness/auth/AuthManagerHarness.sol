// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Brutalizer } from "lib/solady/test/utils/Brutalizer.sol";

import { AuthManager } from "@tsxo/libsol/auth/managed/AuthManager.sol";
import { Owned } from "@tsxo/libsol/auth/Owned.sol";

/// @notice `AuthManager`, managed by an owner.
///
/// @dev Brutalizing harness: every function of the module under test that takes
/// an address, bool, narrow integer, or `bytes4` is overridden to pass its
/// arguments on with dirty unused bits (Solady's `Brutalizer`). Entry points,
/// and the internal functions whose assembly allocates or reads back memory,
/// also fill memory with junk first and check it afterwards. Every test that
/// uses this harness therefore runs with dirty inputs, which only reach
/// assembly through an internal call like this one: the ABI decoder rejects
/// them in calldata.
contract AuthManagerHarness is Owned, AuthManager, Brutalizer {
    constructor(address initialOwner) {
        _initializeOwned(initialOwner);
    }

    function _authorizeManager() internal view override onlyOwner { }

    // =========================================================================
    // Brutalized - Public
    // =========================================================================

    function setUserRole(address user, uint8 role, bool enabled) public override {
        _brutalizeMemory();
        super.setUserRole(_brutalized(user), _brutalizedUint8(role), _brutalized(enabled));
        _checkMemory();
    }

    function setFunctionClosed(address target, bytes4 selector, bool enabled) public override {
        _brutalizeMemory();
        super.setFunctionClosed(_brutalized(target), _brutalizedBytes4(selector), _brutalized(enabled));
        _checkMemory();
    }

    function setFunctionPublic(address target, bytes4 selector, bool enabled) public override {
        _brutalizeMemory();
        super.setFunctionPublic(_brutalized(target), _brutalizedBytes4(selector), _brutalized(enabled));
        _checkMemory();
    }

    function setRoleAccess(address target, bytes4 selector, uint8 role, bool enabled) public override {
        _brutalizeMemory();
        super.setRoleAccess(
            _brutalized(target), _brutalizedBytes4(selector), _brutalizedUint8(role), _brutalized(enabled)
        );
        _checkMemory();
    }

    function setAuthority(address target, address newAuthority) public override {
        _brutalizeMemory();
        super.setAuthority(_brutalized(target), _brutalized(newAuthority));
        _checkMemory();
    }

    function canCall(address user, address target, bytes4 selector) public view override returns (bool result) {
        _brutalizeMemory();
        result = super.canCall(_brutalized(user), _brutalized(target), _brutalizedBytes4(selector));
        _checkMemory();
    }

    function userRoles(address user) public view override returns (uint256 result) {
        _brutalizeMemory();
        result = super.userRoles(_brutalized(user));
        _checkMemory();
    }

    function hasRole(address user, uint8 role) public view override returns (bool result) {
        _brutalizeMemory();
        result = super.hasRole(_brutalized(user), _brutalizedUint8(role));
        _checkMemory();
    }

    function functionAccess(address target, bytes4 selector) public view override returns (uint256 result) {
        _brutalizeMemory();
        result = super.functionAccess(_brutalized(target), _brutalizedBytes4(selector));
        _checkMemory();
    }

    function roleHasAccess(address target, bytes4 selector, uint8 role) public view override returns (bool result) {
        _brutalizeMemory();
        result = super.roleHasAccess(_brutalized(target), _brutalizedBytes4(selector), _brutalizedUint8(role));
        _checkMemory();
    }

    function isFunctionClosed(address target, bytes4 selector) public view override returns (bool result) {
        _brutalizeMemory();
        result = super.isFunctionClosed(_brutalized(target), _brutalizedBytes4(selector));
        _checkMemory();
    }

    function isFunctionPublic(address target, bytes4 selector) public view override returns (bool result) {
        _brutalizeMemory();
        result = super.isFunctionPublic(_brutalized(target), _brutalizedBytes4(selector));
        _checkMemory();
    }

    // =========================================================================
    // Brutalized - Internal
    // =========================================================================

    function _setUserRole(address user, uint8 role, bool enabled) internal override {
        super._setUserRole(_brutalized(user), _brutalizedUint8(role), _brutalized(enabled));
    }

    function _setAccess(address target, bytes4 selector, uint8 shift, bool enabled) internal override {
        super._setAccess(
            _brutalized(target), _brutalizedBytes4(selector), _brutalizedUint8(shift), _brutalized(enabled)
        );
    }

    function _assertValidRole(uint8 role) internal pure override {
        super._assertValidRole(_brutalizedUint8(role));
    }
}
