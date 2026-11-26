// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Brutalizer } from "lib/solady/test/utils/Brutalizer.sol";

import { Initializable } from "@tsxo/libsol/proxy/Initializable.sol";

/// @notice Exposes every guard in `Initializable`.
///
/// @dev Brutalizing harness: `reinitialize` passes its version to the
/// modifier with dirty unused bits (Solady's `Brutalizer`), so every test that
/// uses this harness runs with a dirty version. The other functions take no
/// narrow arguments.
contract InitializableHarness is Initializable, Brutalizer {
    uint256 public value;
    uint256 public parentCalls;

    function initialize(uint256 newValue) external initializer {
        value = newValue;
        _initializeParent();
    }

    function reinitialize(uint64 version, uint256 newValue) external reinitializer(_brutalizedUint64(version)) {
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

/// @notice Runs two `initializer` functions from its constructor, as a contract
/// does when it combines parents that each use the modifier.
contract ConstructorInitializableHarness is Initializable {
    uint256 public a;
    uint256 public b;

    constructor() {
        _initializeA();
        _initializeB();
    }

    function initialize() external initializer { }

    function _initializeA() internal initializer {
        a = 1;
    }

    function _initializeB() internal initializer {
        b = 2;
    }
}

/// @notice An implementation that locks itself in its constructor.
contract DisabledInitializableHarness is Initializable {
    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer { }

    function exposed_initializedVersion() external view returns (uint64) {
        return _getInitializedVersion();
    }
}

/// @notice Runs an `initializer` function from inside another, as a contract
/// does when its initializer calls a parent's.
contract NestedInitializableHarness is Initializable {
    uint256 public outer;
    uint256 public inner;

    constructor(bool nestInConstructor) {
        if (nestInConstructor) _initializeOuter();
    }

    /// @dev The same nesting, after deployment.
    function initialize() external {
        _initializeOuter();
    }

    function exposed_initializedVersion() external view returns (uint64) {
        return _getInitializedVersion();
    }

    function exposed_isInitializing() external view returns (bool) {
        return _isInitializing();
    }

    function _initializeOuter() internal initializer {
        outer = 1;
        _initializeInner();
    }

    function _initializeInner() internal initializer {
        inner = 1;
    }
}
