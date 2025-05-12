// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @dev Does not implement proxiableUUID.
contract NonCompliantContract { }

/// @dev Returns the wrong implementation slot.
contract WrongImplementationSlotContract {
    function proxiableUUID() external pure returns (bytes32) {
        return bytes32(keccak256("WRONG_IMPLEMENTATION_SLOT"));
    }
}
