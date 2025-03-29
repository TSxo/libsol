// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/// @title IAuthority
///
/// @author TSxo
///
/// @notice Interface for permissioning.
interface IAuthority {
    /// @notice Checks whether a caller is allowed to invoke a specific function
    /// on a target contract.
    ///
    /// @param caller   The address calling the function.
    /// @param target   The target contract.
    /// @param selector The target function selector.
    ///
    /// @return result True if the caller is permitted to call the function, false otherwise.
    function canCall(address caller, address target, bytes4 selector) external view returns (bool result);

    /// @notice Updates the Authority of the target contract.
    ///
    /// @param target       The target contract.
    /// @param newAuthority The address of the new Authority.
    function setAuthority(address target, address newAuthority) external;
}
