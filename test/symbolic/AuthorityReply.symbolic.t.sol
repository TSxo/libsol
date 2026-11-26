// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";

import { AuthManaged } from "@tsxo/libsol/auth/managed/AuthManaged.sol";
import { IAuthManaged } from "@tsxo/libsol/auth/managed/IAuthManaged.sol";
import { IPauseManaged } from "@tsxo/libsol/pause/managed/IPauseManaged.sol";
import { PauseManaged } from "@tsxo/libsol/pause/managed/PauseManaged.sol";

/// @notice An authority that answers every query with the word in its slot 0.
contract WordAuthority {
    fallback() external {
        assembly ("memory-safe") {
            mstore(0x00, sload(0))
            return(0x00, 0x20)
        }
    }
}

/// @dev `AuthManaged` and `PauseManaged` behind one function each, without the
/// brutalization in `test/harness/`.
contract SymbolicAuthManaged is AuthManaged {
    uint256 public count;

    constructor(address initialAuthority) {
        _initializeAuthManaged(initialAuthority);
    }

    function increment() external auth {
        count++;
    }
}

/// @dev See `SymbolicAuthManaged`.
contract SymbolicPauseManaged is PauseManaged {
    uint256 public count;

    constructor(address initialAuthority) {
        _initializePauseManaged(initialAuthority);
    }

    function increment() external notPaused {
        count++;
    }
}

/// @notice Symbolic proofs for how `AuthManaged` and `PauseManaged` read their
/// authority's reply.
///
/// The authority's one-word reply is symbolic, so the solver proves the rule
/// for all 2^256 words: only an exact ABI-encoded `true` grants access, and
/// only an exact `false` means not paused. Run with `just symbolic`.
contract AuthorityReplySymbolicTest is Test {
    WordAuthority authority;
    SymbolicAuthManaged authManaged;
    SymbolicPauseManaged pauseManaged;

    function setUp() public {
        authority = new WordAuthority();
        authManaged = new SymbolicAuthManaged(address(authority));
        pauseManaged = new SymbolicPauseManaged(address(authority));
    }

    /// @dev `auth` admits the call only for a reply of exactly 1, and
    /// otherwise reverts with `AuthManaged__Unauthorized`.
    function check_Auth_AdmitsOnlyTrue(uint256 reply) public {
        vm.store(address(authority), 0, bytes32(reply));

        (bool success, bytes memory data) = address(authManaged).call(abi.encodeCall(SymbolicAuthManaged.increment, ()));

        assertEq(success, reply == 1);

        if (!success) {
            assertEq(data, abi.encodeWithSelector(IAuthManaged.AuthManaged__Unauthorized.selector));
        }
    }

    /// @dev `notPaused` admits the call only for a reply of exactly 0, and
    /// otherwise reverts with `PauseManaged__Paused`: any other word fails
    /// closed.
    function check_NotPaused_AdmitsOnlyFalse(uint256 reply) public {
        vm.store(address(authority), 0, bytes32(reply));

        (bool success, bytes memory data) =
            address(pauseManaged).call(abi.encodeCall(SymbolicPauseManaged.increment, ()));

        assertEq(success, reply == 0);

        if (!success) {
            assertEq(data, abi.encodeWithSelector(IPauseManaged.PauseManaged__Paused.selector));
        }
    }
}
