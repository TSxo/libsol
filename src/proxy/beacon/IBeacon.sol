// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/// @title IBeacon
///
/// @author TSxo
///
/// @notice A beacon tells the proxies that point to it which implementation
/// to use.
///
/// See: https://eips.ethereum.org/EIPS/eip-1967#beacon-contract-address
interface IBeacon {
    /// @notice Returns the implementation that proxies using this beacon
    /// delegate to.
    ///
    /// @return The implementation address.
    function implementation() external view returns (address);
}
