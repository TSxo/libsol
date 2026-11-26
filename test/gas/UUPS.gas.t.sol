// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { UUPSUpgradeable as OZUUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { UUPSImplementation } from "@tsxo/libsol/proxy/UUPS/UUPSImplementation.sol";
import { UUPSProxy } from "@tsxo/libsol/proxy/UUPS/UUPSProxy.sol";
import { LibClone } from "solady/utils/LibClone.sol";
import { UUPSUpgradeable as SoladyUUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

address constant ADMIN = address(0xAD);

/// @dev Every implementation has the same surface: a no-op initializer, one
/// view, and an upgrade check against a fixed admin.
contract LibsolImpl is UUPSImplementation {
    function initialize() external { }

    function value() external pure returns (uint256) {
        return 1;
    }

    function _authorizeUpgrade(address) internal view override {
        require(msg.sender == ADMIN);
    }
}

contract OZImpl is OZUUPSUpgradeable {
    function initialize() external { }

    function value() external pure returns (uint256) {
        return 1;
    }

    function _authorizeUpgrade(address) internal view override {
        require(msg.sender == ADMIN);
    }
}

contract SoladyImpl is SoladyUUPSUpgradeable {
    function initialize() external { }

    function value() external pure returns (uint256) {
        return 1;
    }

    function _authorizeUpgrade(address) internal view override {
        require(msg.sender == ADMIN);
    }
}

interface IImpl {
    function initialize() external;
    function value() external view returns (uint256);
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable;
}

/// @notice UUPS proxies: libsol `UUPSProxy` + `UUPSImplementation` vs
/// OpenZeppelin `ERC1967Proxy` + `UUPSUpgradeable` vs a Solady `LibClone`
/// ERC-1967 proxy + `UUPSUpgradeable`.
///
/// The Solady proxy is a minimal bytecode proxy, not a compiled Solidity
/// contract, which is why its deployment and forwarded calls are cheaper.
contract UUPSGasTest is Test {
    bytes constant INIT = abi.encodeWithSignature("initialize()");

    address libsolImpl;
    address ozImpl;
    address soladyImpl;
    address libsolNext;
    address ozNext;
    address soladyNext;

    IImpl libsolProxy;
    IImpl ozProxy;
    IImpl soladyProxy;

    function setUp() public {
        libsolImpl = address(new LibsolImpl());
        ozImpl = address(new OZImpl());
        soladyImpl = address(new SoladyImpl());
        libsolNext = address(new LibsolImpl());
        ozNext = address(new OZImpl());
        soladyNext = address(new SoladyImpl());

        libsolProxy = IImpl(address(new UUPSProxy(libsolImpl, INIT)));
        ozProxy = IImpl(address(new ERC1967Proxy(ozImpl, INIT)));
        soladyProxy = IImpl(LibClone.deployERC1967(soladyImpl));
        soladyProxy.initialize();
    }

    /// @dev Deployment plus the initialization call. The Solady proxy takes no
    /// init data, so its initializer is called separately inside the snapshot.
    function test_DeployProxy() public {
        vm.startSnapshotGas("UUPS", "deploy and initialize proxy / libsol");
        new UUPSProxy(libsolImpl, INIT);
        vm.stopSnapshotGas();

        vm.startSnapshotGas("UUPS", "deploy and initialize proxy / OpenZeppelin");
        new ERC1967Proxy(ozImpl, INIT);
        vm.stopSnapshotGas();

        vm.startSnapshotGas("UUPS", "deploy and initialize proxy / Solady");
        IImpl(LibClone.deployERC1967(soladyImpl)).initialize();
        vm.stopSnapshotGas();
    }

    function test_CallThroughProxy() public {
        libsolProxy.value();
        vm.snapshotGasLastFrame("UUPS", "call through proxy / libsol");

        ozProxy.value();
        vm.snapshotGasLastFrame("UUPS", "call through proxy / OpenZeppelin");

        soladyProxy.value();
        vm.snapshotGasLastFrame("UUPS", "call through proxy / Solady");
    }

    function test_Upgrade() public {
        vm.prank(ADMIN);
        libsolProxy.upgradeToAndCall(libsolNext, "");
        vm.snapshotGasLastFrame("UUPS", "upgradeToAndCall / libsol");

        vm.prank(ADMIN);
        ozProxy.upgradeToAndCall(ozNext, "");
        vm.snapshotGasLastFrame("UUPS", "upgradeToAndCall / OpenZeppelin");

        vm.prank(ADMIN);
        soladyProxy.upgradeToAndCall(soladyNext, "");
        vm.snapshotGasLastFrame("UUPS", "upgradeToAndCall / Solady");
    }
}
