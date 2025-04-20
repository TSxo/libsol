// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

contract ProxiableCounter {
    uint256 public count;

    event Received(uint256 val);
    event Count(uint256 n);

    receive() external payable {
        emit Received(msg.value);
    }

    function setCount(uint256 n) external {
        count = n;
        emit Count(n);
    }

    function increment() external {
        count++;
        emit Count(count);
    }

    function decrement() external {
        count--;
        emit Count(count);
    }

    function fundMe() external payable {
        emit Received(msg.value);
    }
}
