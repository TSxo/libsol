// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { IPauseAuthority } from "@tsxo/libsol/pause/managed/IPauseAuthority.sol";
import { IPauseManaged } from "@tsxo/libsol/pause/managed/IPauseManaged.sol";
import { IPauseManager } from "@tsxo/libsol/pause/managed/IPauseManager.sol";

/// @title PauseManagerReference
///
/// @notice A plain-Solidity reference for `PauseManager`, used to check the
/// assembly version in differential tests. Same behavior, events, and errors.
/// See `src/` for the documentation.
abstract contract PauseManagerReference is IPauseManager, IPauseAuthority {
    bool private _globallyPaused;
    mapping(address target => bool) private _paused;

    function setTargetPaused(address target, bool enabled) public virtual {
        _authorizeManager();
        _paused[target] = enabled;
        emit TargetStatusUpdated(target, enabled);
    }

    function setGloballyPaused(bool enabled) public virtual {
        _authorizeManager();
        _globallyPaused = enabled;
        emit GlobalStatusUpdated(enabled);
    }

    function setPauseAuthority(address target, address newAuthority) public virtual {
        _authorizeManager();
        if (target.code.length == 0) revert PauseManager__InvalidTarget();

        // A low-level call, so that a target that returns data is rejected:
        // `setPauseAuthority` returns nothing.
        (bool success, bytes memory result) =
            target.call(abi.encodeCall(IPauseManaged.setPauseAuthority, (newAuthority)));

        if (!success) {
            assembly ("memory-safe") {
                revert(add(result, 0x20), mload(result))
            }
        }

        if (result.length != 0) revert PauseManager__InvalidTarget();
        emit PauseAuthorityUpdated(target, newAuthority);
    }

    function isPaused(address target) public view virtual returns (bool) {
        return _globallyPaused || _paused[target];
    }

    function isTargetPaused(address target) public view virtual returns (bool) {
        return _paused[target];
    }

    function isGloballyPaused() public view virtual returns (bool) {
        return _globallyPaused;
    }

    function _authorizeManager() internal view virtual;
}
