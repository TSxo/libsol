// SPDX-License-Identifier: MIT
pragma solidity 0.8.39;

import { Brutalizer } from "lib/solady/test/utils/Brutalizer.sol";

import { Initializable } from "@tsxo/libsol/proxy/Initializable.sol";
import { UUPSImplementation } from "@tsxo/libsol/proxy/UUPS/UUPSImplementation.sol";

error Unauthorized();

/// @notice `UUPSImplementation` with its upgrade path brutalized.
///
/// @dev Brutalizing harness: the public upgrade and the internal functions it
/// reaches pass their address on with dirty unused bits (Solady's
/// `Brutalizer`), and `_upgradeToAndCall`, which copies `data` into memory,
/// also fills memory with junk first and checks it afterwards. The address
/// also reaches `_authorizeUpgrade` dirty. Follows Solady's
/// `MockUUPSImplementation`.
abstract contract BrutalizedUUPS is UUPSImplementation, Brutalizer {
    function upgradeToAndCall(address newImplementation, bytes calldata data) public payable virtual override {
        super.upgradeToAndCall(_brutalized(newImplementation), data);
    }

    function _upgradeToAndCall(address newImplementation, bytes memory data) internal virtual override {
        _brutalizeMemory();
        super._upgradeToAndCall(_brutalized(newImplementation), data);
        _checkMemory();
    }

    function _validateImplementation(address newImplementation) internal view virtual override {
        super._validateImplementation(_brutalized(newImplementation));
    }
}

/// @notice A UUPS implementation in the standard shape: it locks itself in its
/// constructor, and the proxy sets the owner through `initialize`.
contract UUPSCounter is BrutalizedUUPS, Initializable {
    uint256 private _count;
    address private _owner;

    event Count(uint256 n);
    event Received(uint256 val);

    constructor() {
        _disableInitializers();
    }

    receive() external payable {
        emit Received(msg.value);
    }

    function initialize(address owner_) external initializer {
        _owner = owner_;
    }

    function count() external view returns (uint256) {
        return _count;
    }

    function increment() external {
        _count += 1;
        emit Count(_count);
    }

    function decrement() external {
        _count -= 1;
        emit Count(_count);
    }

    function setCount(uint256 newCount) external {
        _count = newCount;
        emit Count(_count);
    }

    function fundMe() external payable {
        emit Received(msg.value);
    }

    function owner() external view returns (address) {
        return _owner;
    }

    function _authorizeUpgrade(address) internal view override {
        if (msg.sender != _owner) revert Unauthorized();
    }
}

/// @notice The next version, with the same storage layout plus `upgraded`.
contract UUPSCounterV2 is BrutalizedUUPS, Initializable {
    uint256 private _count;
    address private _owner;
    bool public upgraded;

    event Count(uint256 n);
    event Received(uint256 val);
    event UpgradedV2();

    constructor() {
        _disableInitializers();
    }

    receive() external payable {
        emit Received(msg.value);
    }

    function count() external view returns (uint256) {
        return _count;
    }

    function increment() external {
        _count += 1;
        emit Count(_count);
    }

    function decrement() external {
        _count -= 1;
        emit Count(_count);
    }

    function setCount(uint256 newCount) external {
        _count = newCount;
        emit Count(_count);
    }

    function markAsUpgraded() external {
        upgraded = true;
        emit UpgradedV2();
    }

    function fundMe() external payable {
        emit Received(msg.value);
    }

    function _authorizeUpgrade(address) internal view override {
        if (msg.sender != _owner) revert Unauthorized();
    }
}
