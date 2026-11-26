// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { CallContext } from "@tsxo/libsol/proxy/CallContext.sol";
import { Proxy } from "@tsxo/libsol/proxy/Proxy.sol";

contract CallContextHarness is CallContext {
    function exposed_implementationCall() public view returns (bool) {
        return _implementationCall();
    }

    function exposed_selfAddress() public view returns (address) {
        return _self();
    }

    function exposed_assertImplCall() public view notDelegated { }

    function exposed_assertProxyCall() public view onlyProxy { }
}

contract CallContextProxy is Proxy {
    address immutable _target;

    constructor(address target) {
        _target = target;
    }

    function _implementation() internal view override returns (address result) {
        return _target;
    }
}
