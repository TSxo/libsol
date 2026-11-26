// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { AuthManagedReference } from "test/reference/auth/AuthManagedReference.sol";

contract AuthManagedReferenceHarness is AuthManagedReference {
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
