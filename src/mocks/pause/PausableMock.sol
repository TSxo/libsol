// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { Pausable } from "@tsxo/libsol/pause/Pausable.sol";

contract PausableMock is Pausable {
    uint256 public count;

    function incrementWhenNotPaused() external notPaused {
        count++;
    }

    function incrementWhenPaused() external paused {
        count++;
    }

    function setPaused(bool enabled) external {
        _setPaused(enabled);
    }
}
