// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { Owned } from "@tsxo/libsol/auth/Owned.sol";

contract OwnedImpl is Owned {
    uint256 public count;

    constructor(address initialOwner) {
        _initializeOwned(initialOwner);
    }

    function setCount(uint256 n) external onlyOwner {
        count = n;
    }
}
