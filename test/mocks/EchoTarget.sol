// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

/// @notice Returns its calldata unchanged, so a caller can check that a proxy
/// forwarded the calldata and the return data byte for byte.
contract EchoTarget {
    fallback() external payable {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0x00, calldatasize())
            return(ptr, calldatasize())
        }
    }
}

/// @notice Reverts with its calldata, so a caller can check that a proxy
/// forwarded the revert data byte for byte.
contract RevertEchoTarget {
    fallback() external payable {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0x00, calldatasize())
            revert(ptr, calldatasize())
        }
    }
}
