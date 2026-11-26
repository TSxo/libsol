// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { InitializableReference } from "test/reference/proxy/InitializableReference.sol";

/// @notice The same surface as `InitializableHarness`, over the reference.
contract InitializableReferenceHarness is InitializableReference {
    uint256 public value;
    uint256 public parentCalls;

    function initialize(uint256 newValue) external initializer {
        value = newValue;
        _initializeParent();
    }

    function reinitialize(uint64 version, uint256 newValue) external reinitializer(version) {
        value = newValue;
        _initializeParent();
    }

    /// @dev Calls the `onlyInitializing` function outside an initializer.
    function exposed_initializeParentDirectly() external {
        _initializeParent();
    }

    function exposed_disableInitializers() external {
        _disableInitializers();
    }

    /// @dev Tries to disable initializers from inside an initializer.
    function disableWhileInitializing() external initializer {
        _disableInitializers();
    }

    function exposed_initializedVersion() external view returns (uint64) {
        return _getInitializedVersion();
    }

    function exposed_isInitializing() external view returns (bool) {
        return _isInitializing();
    }

    function _initializeParent() internal onlyInitializing {
        parentCalls++;
    }
}

