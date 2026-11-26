// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { IBeacon } from "@tsxo/libsol/proxy/beacon/IBeacon.sol";

/// @notice A beacon that reports whatever implementation it is given.
contract BeaconMock is IBeacon {
    address public implementation;

    constructor(address implementation_) {
        implementation = implementation_;
    }
}

/// @notice A beacon whose `implementation()` reverts.
contract RevertingBeaconMock {
    function implementation() external pure returns (address) {
        revert("no implementation");
    }
}
