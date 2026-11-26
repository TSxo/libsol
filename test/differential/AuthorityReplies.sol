// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { ScriptedMock } from "test/mocks/ScriptedMock.sol";

import { DifferentialBase } from "./DifferentialBase.sol";

/// @notice A pool of authorities for the `AuthManaged` and `PauseManaged`
/// differential tests, each giving one fixed reply to every query: well
/// formed, malformed, or reverting.
abstract contract AuthorityReplies is DifferentialBase {
    address[] authorities;
    address user = makeAddr("user");

    function _setUpAuthorities() internal {
        // Well formed: allows, denies.
        authorities.push(_mock(false, abi.encode(true)));
        authorities.push(_mock(false, abi.encode(false)));

        // Malformed bool: 2, and 1 with the top bit set.
        authorities.push(_mock(false, abi.encode(uint256(2))));
        authorities.push(_mock(false, abi.encode(uint256(1) | (uint256(1) << 255))));

        // Wrong length: two words, none, one byte.
        authorities.push(_mock(false, abi.encode(true, true)));
        authorities.push(_mock(false, ""));
        authorities.push(_mock(false, hex"01"));

        // Reverts, with and without data.
        authorities.push(_mock(true, abi.encodeWithSignature("Error(string)", "denied")));
        authorities.push(_mock(true, ""));

        // No code: rejected by `setAuthority` and `setPauseAuthority`.
        authorities.push(makeAddr("eoa"));
    }

    /// @dev The current authority, so that changes go through, or an outsider.
    function _caller(bool byAuthority, address current) internal view returns (address) {
        return byAuthority ? current : user;
    }

    function _authority(uint256 seed) internal view returns (address) {
        return authorities[bound(seed, 0, authorities.length - 1)];
    }

    function _mock(bool reverts, bytes memory data) internal returns (address) {
        return address(new ScriptedMock(reverts, data));
    }
}
