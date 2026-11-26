// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

/// @title InitializableReference
///
/// @notice A plain-Solidity reference for `Initializable`, used to check the
/// assembly version in differential tests. Same behavior, events, and errors.
/// See `src/` for the documentation.
abstract contract InitializableReference {
    /// @custom:storage-location erc7201:libsol.storage.Initializable
    struct InitializableStorage {
        uint64 initialized;
        bool initializing;
    }

    /// @dev keccak256(abi.encode(uint256(keccak256("libsol.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant INITIALIZABLE_SLOT = 0x228350bbb6ec721cd1284fd173ffc256e19d432aa81362824fe0149938a6fa00;

    event Initialized(uint64 version);

    error Initializable__InvalidInitialization();
    error Initializable__NotInitializing();

    modifier initializer() {
        InitializableStorage storage $ = _getInitializableStorage();

        // Allowed for the first top-level call, or for further initializers
        // while version 1 is being constructed (no code deployed yet).
        bool isTopLevelCall = !$.initializing;
        bool isFirstCall = isTopLevelCall && $.initialized == 0;
        bool isConstruction = $.initialized == 1 && address(this).code.length == 0;

        if (!isFirstCall && !isConstruction) revert Initializable__InvalidInitialization();

        $.initialized = 1;
        if (isTopLevelCall) {
            $.initializing = true;

            // forge-lint: disable-next-line(reentrancy-events) -- no external call precedes it.
            emit Initialized(1);
        }

        _;

        if (isTopLevelCall) $.initializing = false;
    }

    modifier reinitializer(uint64 version) {
        InitializableStorage storage $ = _getInitializableStorage();

        if ($.initializing || $.initialized >= version) revert Initializable__InvalidInitialization();

        $.initialized = version;
        $.initializing = true;

        // forge-lint: disable-next-line(reentrancy-events) -- no external call precedes it.
        emit Initialized(version);

        _;

        $.initializing = false;
    }

    modifier onlyInitializing() {
        _assertInitializing();
        _;
    }

    function _disableInitializers() internal virtual {
        InitializableStorage storage $ = _getInitializableStorage();

        if ($.initializing) revert Initializable__InvalidInitialization();

        if ($.initialized != type(uint64).max) {
            $.initialized = type(uint64).max;

            // forge-lint: disable-next-line(reentrancy-events) -- no external call precedes it.
            emit Initialized(type(uint64).max);
        }
    }

    function _getInitializedVersion() internal view virtual returns (uint64) {
        return _getInitializableStorage().initialized;
    }

    function _isInitializing() internal view virtual returns (bool) {
        return _getInitializableStorage().initializing;
    }

    function _assertInitializing() internal view virtual {
        if (!_getInitializableStorage().initializing) revert Initializable__NotInitializing();
    }

    function _getInitializableStorage() private pure returns (InitializableStorage storage $) {
        assembly ("memory-safe") {
            $.slot := INITIALIZABLE_SLOT
        }
    }
}
