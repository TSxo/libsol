// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

/// @notice Holds the bytes a `ScriptedMock` answers with.
contract ScriptedReply {
    bytes public data;

    constructor(bytes memory data_) {
        data = data_;
    }
}

/// @notice Answers every call with fixed bytes, returned or reverted raw.
///
/// @dev Stands in for a beacon, an implementation, an authority, or a target,
/// including malformed ones: a dirty word, too few or too many bytes, or a
/// revert with data.
///
/// The bytes live in a child `ScriptedReply`, not in this contract's storage.
/// Under `delegatecall` this contract's code runs against the caller's
/// storage.
contract ScriptedMock {
    bool private immutable reverts;
    ScriptedReply private immutable reply;

    constructor(bool reverts_, bytes memory data) {
        reverts = reverts_;
        reply = new ScriptedReply(data);
    }

    /// @dev Returns the bytes raw, or reverts with them. Solidity has no way to
    /// revert with arbitrary bytes, hence the one line of assembly.
    fallback(bytes calldata) external payable returns (bytes memory data) {
        data = reply.data();

        if (reverts) {
            assembly ("memory-safe") {
                revert(add(data, 0x20), mload(data))
            }
        }
    }
}
