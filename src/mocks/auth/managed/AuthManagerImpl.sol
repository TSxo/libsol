// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { AuthManager } from "@tsxo/libsol/auth/managed/AuthManager.sol";
import { Owned } from "@tsxo/libsol/auth/Owned.sol";

contract AuthManagerImpl is Owned, AuthManager {
    constructor(address initialOwner) {
        _initializeOwned(initialOwner);
    }
}
