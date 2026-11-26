// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { PauseManagerReference } from "test/reference/pause/PauseManagerReference.sol";
import { Owned } from "@tsxo/libsol/auth/Owned.sol";

contract PauseManagerReferenceHarness is Owned, PauseManagerReference {
    constructor(address initialOwner) {
        _initializeOwned(initialOwner);
    }

    function _authorizeManager() internal view override onlyOwner { }
}
