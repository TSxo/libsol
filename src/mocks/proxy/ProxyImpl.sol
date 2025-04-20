// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { Proxy } from "@tsxo/libsol/proxy/Proxy.sol";

contract ProxyImpl is Proxy {
    address immutable _target;

    constructor(address target) {
        _target = target;
    }

    function _implementation() internal view override returns (address result) {
        return _target;
    }
}
