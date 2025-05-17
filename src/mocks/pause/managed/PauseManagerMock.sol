// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { PauseManager } from "@tsxo/libsol/pause/managed/PauseManager.sol";
import { Owned } from "@tsxo/libsol/auth/Owned.sol";

contract PauseManagerMock is Owned, PauseManager {
    constructor(address initialOwner) {
        _initializeOwned(initialOwner);
    }
}
