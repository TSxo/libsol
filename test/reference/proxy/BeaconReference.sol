// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Owned } from "@tsxo/libsol/auth/Owned.sol";
import { IBeacon } from "@tsxo/libsol/proxy/beacon/IBeacon.sol";
import { IUpgradeableBeacon } from "@tsxo/libsol/proxy/beacon/IUpgradeableBeacon.sol";
import { Proxy } from "@tsxo/libsol/proxy/Proxy.sol";

import { ERC1967Reference } from "./ERC1967Reference.sol";

/// @title UpgradeableBeaconReference
///
/// @notice A plain-Solidity reference for `UpgradeableBeacon`, used to check
/// the assembly version in differential tests. Same behavior, events and
/// errors. See `src/` for the documentation.
contract UpgradeableBeaconReference is Owned, IUpgradeableBeacon {
    address private _implementation;

    constructor(address initialOwner, address initialImplementation) {
        _initializeOwned(initialOwner);
        _setImplementation(initialImplementation);
    }

    function upgradeTo(address newImplementation) public virtual onlyOwner {
        _setImplementation(newImplementation);
    }

    function implementation() public view virtual returns (address) {
        return _implementation;
    }

    function _setImplementation(address newImplementation) internal virtual {
        if (newImplementation.code.length == 0) revert UpgradeableBeacon__InvalidImplementation();
        emit Upgraded(newImplementation);
        _implementation = newImplementation;
    }
}

/// @title BeaconProxyReference
///
/// @notice A plain-Solidity reference for `BeaconProxy`.
contract BeaconProxyReference is Proxy, ERC1967Reference {
    address private immutable _beacon;

    constructor(address beacon, bytes memory data) payable {
        _upgradeBeaconToAndCall(beacon, data);
        _beacon = beacon;
    }

    function _implementation() internal view override returns (address) {
        // A low-level call, so that a reply that is not exactly one word is
        // rejected rather than decoded.
        (bool success, bytes memory result) = _beacon.staticcall(abi.encodeCall(IBeacon.implementation, ()));

        if (!success) {
            assembly ("memory-safe") {
                revert(add(result, 0x20), mload(result))
            }
        }

        if (result.length != 32) revert ERC1967__InvalidBeacon();
        return address(uint160(uint256(bytes32(result))));
    }
}
