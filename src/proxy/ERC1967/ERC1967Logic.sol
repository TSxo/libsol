// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/// @title ERC1967Logic
///
/// @author TSxo
///
/// @dev This abstract contract provides the core components of ERC-1967 that are
/// specific to logic (implementation) contracts. It exposes the standardized
/// storage slot used by proxies to reference the implementation address, as well
/// as the event and error definitions needed to support upgradeability.
///
/// See: https://eips.ethereum.org/EIPS/eip-1967
abstract contract ERC1967Logic {
    // -------------------------------------------------------------------------
    // State

    /// @dev bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @dev keccak256(bytes("Upgraded(address)"))
    bytes32 internal constant UPGRADED = 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b;

    // -------------------------------------------------------------------------
    // Events

    /// @notice Emitted when the implementation address is updated.
    ///
    /// @param implementation The new implementation address.
    event Upgraded(address indexed implementation);

    // -------------------------------------------------------------------------
    // Errors

    /// @notice Raised when updating the implementation address fails.
    error ERC1967Logic__UpgradeFailed();
}
