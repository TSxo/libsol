// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { UUPSImplementation } from "@tsxo/libsol/proxy/UUPS/UUPSImplementation.sol";

error Unauthorized();
error AlreadyInitialized();

contract UUPSCounterMock is UUPSImplementation {
    uint256 private _count;
    address private _owner;

    event Count(uint256 n);
    event Received(uint256 val);

    constructor() {
        _owner = msg.sender;
    }

    receive() external payable {
        emit Received(msg.value);
    }

    function initialize() external {
        if (_owner != address(0)) revert AlreadyInitialized();
        _owner = msg.sender;
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

    function _authorizeUpgrade(address) internal override {
        if (msg.sender != _owner) revert Unauthorized();
    }
}

contract UUPSCounterV2Mock is UUPSImplementation {
    uint256 private _count;
    address private _owner;
    bool public upgraded;

    event Count(uint256 n);
    event Received(uint256 val);
    event UpgradedV2();

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
