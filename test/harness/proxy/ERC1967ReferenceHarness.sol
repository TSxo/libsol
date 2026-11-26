// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { ERC1822Reference, ERC1967Reference } from "test/reference/proxy/ERC1967Reference.sol";

/// @notice Exposes the `ERC1967Reference` helpers, with the default implementation
/// check (code only).
contract ERC1967ReferenceHarness is ERC1967Reference {
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
}

/// @notice Exposes `_upgradeToAndCall` with the ERC-1822 implementation check.
contract ERC1822ReferenceHarness is ERC1822Reference {
    function exposed_upgradeToAndCall(address newImplementation, bytes memory data) external payable {
        _upgradeToAndCall(newImplementation, data);
    }

    function exposed_implementation() external view returns (address) {
        return _getImplementation();
    }
}
