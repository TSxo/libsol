// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

/// @notice A stand-in Authority and Pause Authority whose answers to `canCall`
/// and `isPaused` are set by the test, including malformed and reverting ones.
contract AuthorityMock {
    enum Mode {
        ReturnWord, // Return `word` as a 32-byte value.
        ReturnShort, // Return a single byte.
        Revert // Revert with `Rejected()`.
    }

    error Rejected();

    Mode public mode;
    uint256 public word;

    function configure(Mode newMode, uint256 newWord) external {
        mode = newMode;
        word = newWord;
    }

    /// @dev Returns a raw word rather than `bool`, so the test can send values
    /// other than 0 and 1. The callers read the word in assembly.
    function canCall(address, address, bytes4) external view returns (uint256) {
        return _answer();
    }

    function isPaused(address) external view returns (uint256) {
        return _answer();
    }

    function _answer() private view returns (uint256) {
        if (mode == Mode.Revert) revert Rejected();

        uint256 w = word;
        if (mode == Mode.ReturnShort) {
            assembly ("memory-safe") {
                mstore(0x00, w)
                return(0x1f, 0x01)
            }
        }

        return w;
    }
}

/// @notice A target whose `setAuthority` and `setPauseAuthority` always revert.
contract RevertingTarget {
    error Refused();

    function setAuthority(address) external pure {
        revert Refused();
    }

    function setPauseAuthority(address) external pure {
        revert Refused();
    }
}
