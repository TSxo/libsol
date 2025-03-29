// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { AuthManaged } from "@tsxo/libsol/auth/managed/AuthManaged.sol";

contract AuthManagedImpl is AuthManaged {
    uint256 public count;

    constructor(address initialAuthority) {
        _initializeAuthManaged(initialAuthority);
    }

    function increment() external auth {
        count++;
    }

    function decrement() external auth {
        count--;
    }
}
