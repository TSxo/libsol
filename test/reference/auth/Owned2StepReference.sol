// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { IOwned } from "@tsxo/libsol/auth/IOwned.sol";
import { IOwned2Step } from "@tsxo/libsol/auth/IOwned2Step.sol";
import { Owned } from "@tsxo/libsol/auth/Owned.sol";

/// @title Owned2StepReference
///
/// @notice A plain-Solidity reference for `Owned2Step`, used to check the
/// assembly version in differential tests. Same behavior, events, and errors.
abstract contract Owned2StepReference is Owned, IOwned2Step {
    address private _pendingOwner;

    function transferOwnership(address newOwner) public virtual override(IOwned, Owned) onlyOwner {
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(msg.sender, newOwner);
    }

    function acceptOwnership() public virtual {
        if (msg.sender != _pendingOwner) revert Owned2Step__NotPendingOwner();
        _transferOwnership(msg.sender);
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }

    function _transferOwnership(address newOwner) internal virtual override {
        delete _pendingOwner;
        super._transferOwnership(newOwner);
    }
}
