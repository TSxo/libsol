// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { PauseManagedReference } from "test/reference/pause/PauseManagedReference.sol";

contract PauseManagedReferenceHarness is PauseManagedReference {
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

    function countWhenNotPaused() external view notPaused returns (uint256) {
        return count;
    }
}
