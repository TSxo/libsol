// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { IAuthManaged } from "@tsxo/libsol/auth/managed/IAuthManaged.sol";
import { IAuthority } from "@tsxo/libsol/auth/managed/IAuthority.sol";

/// @title AuthManagedReference
///
/// @notice A plain-Solidity reference for `AuthManaged`, used to check the
/// assembly version in differential tests. Same behavior, events, and errors.
/// See `src/` for the documentation.
abstract contract AuthManagedReference is IAuthManaged {
    address private _authority;

    modifier auth() {
        _assertAuthorized(msg.sender, msg.sig);
        _;
    }

    function _initializeAuthManaged(address initialAuthority) internal virtual {
        _setAuthority(initialAuthority);
    }

    function setAuthority(address newAuthority) public virtual {
        if (msg.sender != _authority) revert AuthManaged__Unauthorized();
        _setAuthority(newAuthority);
    }

    function authority() public view virtual returns (address) {
        return _authority;
    }

    function _setAuthority(address newAuthority) internal virtual {
        if (newAuthority.code.length == 0) revert AuthManaged__InvalidAuthority();
        emit AuthorityUpdated(_authority, newAuthority);
        _authority = newAuthority;
    }

    function _assertAuthorized(address user, bytes4 selector) internal view virtual {
        // A low-level call, so that the reply can be checked exactly: one word,
        // equal to an ABI-encoded `true`.
        (bool success, bytes memory result) =
            _authority.staticcall(abi.encodeCall(IAuthority.canCall, (user, address(this), selector)));

        if (!success) {
            assembly ("memory-safe") {
                revert(add(result, 0x20), mload(result))
            }
        }

        if (result.length != 32) revert AuthManaged__InvalidAuthority();
        if (uint256(bytes32(result)) != 1) revert AuthManaged__Unauthorized();
    }
}
