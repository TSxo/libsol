// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { IPauseAuthority } from "@tsxo/libsol/pause/managed/IPauseAuthority.sol";
import { IPauseManaged } from "@tsxo/libsol/pause/managed/IPauseManaged.sol";

/// @title PauseManagedReference
///
/// @notice A plain-Solidity reference for `PauseManaged`, used to check the
/// assembly version in differential tests. Same behavior, events, and errors.
/// See `src/` for the documentation.
abstract contract PauseManagedReference is IPauseManaged {
    address private _pauseAuthority;

    modifier notPaused() {
        _assertNotPaused();
        _;
    }

    function _initializePauseManaged(address initialAuthority) internal virtual {
        _setPauseAuthority(initialAuthority);
    }

    function setPauseAuthority(address newAuthority) public virtual {
        if (msg.sender != _pauseAuthority) revert PauseManaged__Unauthorized();
        _setPauseAuthority(newAuthority);
    }

    function pauseAuthority() public view virtual returns (address) {
        return _pauseAuthority;
    }

    function _setPauseAuthority(address newAuthority) internal virtual {
        if (newAuthority.code.length == 0) revert PauseManaged__InvalidAuthority();
        emit PauseAuthorityUpdated(_pauseAuthority, newAuthority);
        _pauseAuthority = newAuthority;
    }

    function _assertNotPaused() internal view virtual {
        // A low-level call, so that the reply can be checked exactly: one word,
        // where anything but zero counts as paused.
        (bool success, bytes memory result) =
            _pauseAuthority.staticcall(abi.encodeCall(IPauseAuthority.isPaused, (address(this))));

        if (!success) {
            assembly ("memory-safe") {
                revert(add(result, 0x20), mload(result))
            }
        }

        if (result.length != 32) revert PauseManaged__InvalidAuthority();
        if (uint256(bytes32(result)) != 0) revert PauseManaged__Paused();
    }
}
