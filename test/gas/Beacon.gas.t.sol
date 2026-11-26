// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";

import { BeaconProxy as OZBeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { UpgradeableBeacon as OZUpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import { BeaconProxy } from "@tsxo/libsol/proxy/beacon/BeaconProxy.sol";
import { UpgradeableBeacon } from "@tsxo/libsol/proxy/beacon/UpgradeableBeacon.sol";

import { LibClone } from "solady/utils/LibClone.sol";
import { UpgradeableBeacon as SoladyUpgradeableBeacon } from "solady/utils/UpgradeableBeacon.sol";

/// @dev The implementation behind every beacon. It needs nothing from a
/// library, so all three set-ups share it.
contract BeaconImpl {
    function initialize() external { }

    function value() external pure returns (uint256) {
        return 1;
    }
}

interface IBeaconImpl {
    function initialize() external;
    function value() external view returns (uint256);
}

interface IUpgradeTo {
    function upgradeTo(address newImplementation) external;
}

/// @notice Beacon proxies: libsol `BeaconProxy` and `UpgradeableBeacon` vs
/// OpenZeppelin's vs Solady's `UpgradeableBeacon` with a `LibClone` beacon
/// proxy.
///
/// @dev Solady's proxy is minimal bytecode from `LibClone`, not a compiled
/// contract, so it is cheaper to deploy. It reads the beacon from the ERC-1967
/// slot on each call, a cold storage read; the libsol and OpenZeppelin proxies
/// keep it in an immutable.
contract BeaconGasTest is Test {
    bytes constant INIT = abi.encodeWithSignature("initialize()");

    address owner = makeAddr("owner");
    address impl;
    address nextImpl;

    address libsolBeacon;
    address ozBeacon;
    address soladyBeacon;

    IBeaconImpl libsolProxy;
    IBeaconImpl ozProxy;
    IBeaconImpl soladyProxy;

    function setUp() public {
        impl = address(new BeaconImpl());
        nextImpl = address(new BeaconImpl());

        libsolBeacon = address(new UpgradeableBeacon(owner, impl));
        ozBeacon = address(new OZUpgradeableBeacon(impl, owner));
        soladyBeacon = address(new SoladyUpgradeableBeacon(owner, impl));

        libsolProxy = IBeaconImpl(address(new BeaconProxy(libsolBeacon, INIT)));
        ozProxy = IBeaconImpl(address(new OZBeaconProxy(ozBeacon, INIT)));
        soladyProxy = IBeaconImpl(LibClone.deployERC1967BeaconProxy(soladyBeacon));
        soladyProxy.initialize();
    }

    /// @dev Deployment plus the initialization call. The Solady proxy takes no
    /// init data, so its initializer is called separately inside the snapshot.
    function test_DeployProxy() public {
        vm.startSnapshotGas("Beacon", "deploy and initialize proxy / libsol");
        new BeaconProxy(libsolBeacon, INIT);
        vm.stopSnapshotGas();

        vm.startSnapshotGas("Beacon", "deploy and initialize proxy / OpenZeppelin");
        new OZBeaconProxy(ozBeacon, INIT);
        vm.stopSnapshotGas();

        vm.startSnapshotGas("Beacon", "deploy and initialize proxy / Solady");
        IBeaconImpl(LibClone.deployERC1967BeaconProxy(soladyBeacon)).initialize();
        vm.stopSnapshotGas();
    }

    function test_CallThroughProxy() public {
        libsolProxy.value();
        vm.snapshotGasLastFrame("Beacon", "call through proxy / libsol");

        ozProxy.value();
        vm.snapshotGasLastFrame("Beacon", "call through proxy / OpenZeppelin");

        soladyProxy.value();
        vm.snapshotGasLastFrame("Beacon", "call through proxy / Solady");
    }

    function test_UpgradeBeacon() public {
        vm.prank(owner);
        IUpgradeTo(libsolBeacon).upgradeTo(nextImpl);
        vm.snapshotGasLastFrame("Beacon", "beacon upgradeTo / libsol");

        vm.prank(owner);
        IUpgradeTo(ozBeacon).upgradeTo(nextImpl);
        vm.snapshotGasLastFrame("Beacon", "beacon upgradeTo / OpenZeppelin");

        vm.prank(owner);
        IUpgradeTo(soladyBeacon).upgradeTo(nextImpl);
        vm.snapshotGasLastFrame("Beacon", "beacon upgradeTo / Solady");
    }
}
