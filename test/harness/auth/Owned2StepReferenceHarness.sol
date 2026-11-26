// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Owned2StepReference } from "test/reference/auth/Owned2StepReference.sol";

contract Owned2StepReferenceHarness is Owned2StepReference {
    uint256 public count;

    constructor(address initialOwner) {
        _initializeOwned(initialOwner);
    }

    function setCount(uint256 n) external onlyOwner {
        count = n;
    }
}
