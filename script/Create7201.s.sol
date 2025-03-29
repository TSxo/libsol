// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

contract Create7201 is Script {
    function run() external view {
        string memory id = vm.envString("ID");
        bytes32 loc = keccak256(abi.encode(uint256(keccak256(bytes(id))) - 1)) & ~bytes32(uint256(0xff));
        console.logBytes32(loc);
    }
}
