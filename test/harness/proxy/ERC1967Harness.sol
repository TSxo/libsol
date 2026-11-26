// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Brutalizer } from "lib/solady/test/utils/Brutalizer.sol";

import { ERC1967 } from "@tsxo/libsol/proxy/ERC1967/ERC1967.sol";
import { ERC1822 } from "@tsxo/libsol/proxy/UUPS/ERC1822.sol";

/// @notice Exposes the `ERC1967` helpers, with the default implementation
/// check (code only).
///
/// @dev Brutalizing harness: every function of the module under test that takes
/// an address, bool, narrow integer, or `bytes4` is overridden to pass its
/// arguments on with dirty unused bits (Solady's `Brutalizer`). Entry points,
/// and the internal functions whose assembly allocates or reads back memory,
/// also fill memory with junk first and check it afterwards. Every test that
/// uses this harness therefore runs with dirty inputs, which only reach
/// assembly through an internal call like this one: the ABI decoder rejects
/// them in calldata.
contract ERC1967Harness is ERC1967, Brutalizer {
    function exposed_upgradeToAndCall(address newImplementation, bytes memory data) external payable {
        _upgradeToAndCall(newImplementation, data);
    }

    function exposed_changeAdmin(address newAdmin) external {
        _changeAdmin(newAdmin);
    }

    function exposed_upgradeBeaconToAndCall(address newBeacon, bytes memory data) external payable {
        _upgradeBeaconToAndCall(newBeacon, data);
    }

    function exposed_implementation() external view returns (address) {
        return _getImplementation();
    }

    function exposed_admin() external view returns (address) {
        return _getAdmin();
    }

    function exposed_beacon() external view returns (address) {
        return _getBeacon();
    }

    // =========================================================================
    // Brutalized - Internal
    // =========================================================================

    function _upgradeToAndCall(address newImplementation, bytes memory data) internal override {
        _brutalizeMemory();
        super._upgradeToAndCall(_brutalized(newImplementation), data);
        _checkMemory();
    }

    function _validateImplementation(address newImplementation) internal view override {
        super._validateImplementation(_brutalized(newImplementation));
    }

    function _changeAdmin(address newAdmin) internal override {
        _brutalizeMemory();
        super._changeAdmin(_brutalized(newAdmin));
        _checkMemory();
    }

    function _upgradeBeaconToAndCall(address newBeacon, bytes memory data) internal override {
        _brutalizeMemory();
        super._upgradeBeaconToAndCall(_brutalized(newBeacon), data);
        _checkMemory();
    }
}

/// @notice Exposes `_upgradeToAndCall` with the ERC-1822 implementation check.
///
/// @dev Brutalizing harness: every function of the module under test that takes
/// an address, bool, narrow integer, or `bytes4` is overridden to pass its
/// arguments on with dirty unused bits (Solady's `Brutalizer`). Entry points,
/// and the internal functions whose assembly allocates or reads back memory,
/// also fill memory with junk first and check it afterwards. Every test that
/// uses this harness therefore runs with dirty inputs, which only reach
/// assembly through an internal call like this one: the ABI decoder rejects
/// them in calldata.
contract ERC1822Harness is ERC1822, Brutalizer {
    function exposed_upgradeToAndCall(address newImplementation, bytes memory data) external payable {
        _upgradeToAndCall(newImplementation, data);
    }

    function exposed_implementation() external view returns (address) {
        return _getImplementation();
    }

    // =========================================================================
    // Brutalized - Internal
    // =========================================================================

    function _upgradeToAndCall(address newImplementation, bytes memory data) internal override {
        _brutalizeMemory();
        super._upgradeToAndCall(_brutalized(newImplementation), data);
        _checkMemory();
    }

    function _validateImplementation(address newImplementation) internal view override {
        super._validateImplementation(_brutalized(newImplementation));
    }
}
