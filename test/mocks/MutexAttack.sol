// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

/// @notice Calls back into the sender to attempt reentrancy.
contract MutexAttack {
    error Failed();

    function execute(bytes4 selector) external {
        (bool success,) = msg.sender.call(abi.encodeWithSelector(selector));

        if (!success) revert Failed();
    }
}
