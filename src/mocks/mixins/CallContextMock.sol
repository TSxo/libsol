// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { CallContext } from "@tsxo/libsol/mixins/CallContext.sol";
import { Proxy } from "@tsxo/libsol/proxy/Proxy.sol";

contract CallContextMock is CallContext {
    function implementationCall() public view returns (bool) {
        return _implementationCall();
    }

    function selfAddress() public view returns (address) {
        return _self();
    }

    function assertImplCall() public view notDelegated { }

    function assertProxyCall() public view onlyProxy { }
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
