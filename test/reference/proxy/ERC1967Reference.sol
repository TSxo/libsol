// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { IBeacon } from "@tsxo/libsol/proxy/beacon/IBeacon.sol";

/// @title ERC1967Reference
///
/// @notice A plain-Solidity reference for `ERC1967`, used to check the
/// assembly version in differential tests. Same behavior, events, and errors.
/// See `src/` for the documentation.
///
/// The slots are computed from the EIP's formula rather than copied, so a
/// wrong constant in `src/` shows up as a difference.
abstract contract ERC1967Reference {
    struct AddressSlot {
        address value;
    }

    bytes32 internal constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
    bytes32 internal constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
    bytes32 internal constant BEACON_SLOT = bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1);

    event Upgraded(address indexed implementation);
    event AdminChanged(address previousAdmin, address newAdmin);
    event BeaconUpgraded(address indexed beacon);

    error ERC1967__UpgradeFailed();
    error ERC1967__InvalidAdmin();
    error ERC1967__InvalidBeacon();

    function _getImplementation() internal view virtual returns (address) {
        return _slot(IMPLEMENTATION_SLOT).value;
    }

    function _upgradeToAndCall(address newImplementation, bytes memory data) internal virtual {
        _validateImplementation(newImplementation);

        emit Upgraded(newImplementation);

        _slot(IMPLEMENTATION_SLOT).value = newImplementation;
        _delegateCallIfData(newImplementation, data);
    }

    function _validateImplementation(address newImplementation) internal view virtual {
        if (newImplementation.code.length == 0) revert ERC1967__UpgradeFailed();
    }

    function _getAdmin() internal view virtual returns (address) {
        return _slot(ADMIN_SLOT).value;
    }

    function _changeAdmin(address newAdmin) internal virtual {
        if (newAdmin == address(0)) revert ERC1967__InvalidAdmin();
        emit AdminChanged(_getAdmin(), newAdmin);
        _slot(ADMIN_SLOT).value = newAdmin;
    }

    function _getBeacon() internal view virtual returns (address) {
        return _slot(BEACON_SLOT).value;
    }

    function _upgradeBeaconToAndCall(address newBeacon, bytes memory data) internal virtual {
        // A low-level call, so that a beacon without code, a revert, or a reply
        // that is not exactly one word all become `ERC1967__InvalidBeacon`.
        (bool success, bytes memory result) = newBeacon.staticcall(abi.encodeCall(IBeacon.implementation, ()));
        if (!success || result.length != 32) revert ERC1967__InvalidBeacon();

        address implementation = address(uint160(uint256(bytes32(result))));
        if (implementation.code.length == 0) revert ERC1967__InvalidBeacon();

        emit BeaconUpgraded(newBeacon);
        _slot(BEACON_SLOT).value = newBeacon;
        _delegateCallIfData(implementation, data);
    }

    function _delegateCallIfData(address target, bytes memory data) private {
        if (data.length == 0) return;

        (bool success, bytes memory result) = target.delegatecall(data);
        if (!success) {
            assembly ("memory-safe") {
                revert(add(result, 0x20), mload(result))
            }
        }
    }

    function _slot(bytes32 slot) private pure returns (AddressSlot storage result) {
        assembly ("memory-safe") {
            result.slot := slot
        }
    }
}

/// @title ERC1822Reference
///
/// @notice A plain-Solidity reference for `ERC1822`.
abstract contract ERC1822Reference is ERC1967Reference {
    function _validateImplementation(address newImplementation) internal view virtual override {
        (bool success, bytes memory result) = newImplementation.staticcall(abi.encodeWithSignature("proxiableUUID()"));

        if (!success || result.length != 32 || bytes32(result) != IMPLEMENTATION_SLOT) {
            revert ERC1967__UpgradeFailed();
        }
    }
}
