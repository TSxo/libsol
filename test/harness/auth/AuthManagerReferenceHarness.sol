// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { AuthManagerReference } from "test/reference/auth/AuthManagerReference.sol";
import { Owned } from "@tsxo/libsol/auth/Owned.sol";

contract AuthManagerReferenceHarness is Owned, AuthManagerReference {
    constructor(address initialOwner) {
        _initializeOwned(initialOwner);
    }

    function _authorizeManager() internal view override onlyOwner { }
}
