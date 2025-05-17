// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { PauseManaged } from "@tsxo/libsol/pause/managed/PauseManaged.sol";

contract PauseManagedMock is PauseManaged {
    uint256 public count;

    constructor(address initialAuthority) {
        _initializePauseManaged(initialAuthority);
    }

    function increment() external notPaused {
        count++;
    }

    function decrement() external notPaused {
        count--;
    }
}
