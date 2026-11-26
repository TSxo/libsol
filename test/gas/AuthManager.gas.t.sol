// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";

import { AccessManaged } from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";

import { AuthManaged } from "@tsxo/libsol/auth/managed/AuthManaged.sol";
import { AuthManager } from "@tsxo/libsol/auth/managed/AuthManager.sol";
import { Owned } from "@tsxo/libsol/auth/Owned.sol";

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";

/// @dev `AuthManager` managed by an owner, without the brutalization in
/// `test/harness/`, which would distort the measurements.
contract LibsolManager is Owned, AuthManager {
    constructor(address initialOwner) {
        _initializeOwned(initialOwner);
    }

    function _authorizeManager() internal view override onlyOwner { }
}

contract LibsolManagedTarget is AuthManaged {
    constructor(address authority) {
        _initializeAuthManaged(authority);
    }

    function guarded() external auth { }
}

contract OZManagedTarget is AccessManaged {
    constructor(address authority) AccessManaged(authority) { }

    function guarded() external restricted { }
}

/// @dev Solady keeps roles in the target itself, so there is no external
/// authority call. Included as a reference point, not a like-for-like match.
contract SoladyRolesTarget is OwnableRoles {
    uint256 public constant ROLE = 1 << 1;

    constructor(address owner_) {
        _initializeOwner(owner_);
    }

    function guarded() external onlyRoles(ROLE) { }
}

/// @notice Role-based access: libsol `AuthManager` + `AuthManaged` vs
/// OpenZeppelin `AccessManager` + `AccessManaged` vs Solady `OwnableRoles`.
///
/// `AccessManager` also supports execution delays, scheduling, and guardians,
/// which libsol does not; part of its cost pays for those features.
contract AuthManagerGasTest is Test {
    address admin = makeAddr("admin");
    address user = makeAddr("user");
    address newUser = makeAddr("new-user");
    uint8 constant ROLE = 1;

    LibsolManager libsolManager;
    LibsolManagedTarget libsolTarget;

    AccessManager ozManager;
    OZManagedTarget ozTarget;

    SoladyRolesTarget soladyTarget;

    function setUp() public {
        libsolManager = new LibsolManager(admin);
        libsolTarget = new LibsolManagedTarget(address(libsolManager));

        ozManager = new AccessManager(admin);
        ozTarget = new OZManagedTarget(address(ozManager));

        soladyTarget = new SoladyRolesTarget(admin);

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = LibsolManagedTarget.guarded.selector;

        vm.startPrank(admin);
        libsolManager.setUserRole(user, ROLE, true);
        libsolManager.setRoleAccess(address(libsolTarget), selectors[0], ROLE, true);

        ozManager.setTargetFunctionRole(address(ozTarget), selectors, ROLE);
        ozManager.grantRole(ROLE, user, 0);

        soladyTarget.grantRoles(user, soladyTarget.ROLE());
        vm.stopPrank();
    }

    function test_RestrictedCall() public {
        vm.prank(user);
        libsolTarget.guarded();
        vm.snapshotGasLastFrame("AuthManager", "role-restricted call / libsol");

        vm.prank(user);
        ozTarget.guarded();
        vm.snapshotGasLastFrame("AuthManager", "role-restricted call / OpenZeppelin");

        vm.prank(user);
        soladyTarget.guarded();
        vm.snapshotGasLastFrame("AuthManager", "role-restricted call / Solady OwnableRoles");
    }

    function test_GrantRole() public {
        uint256 soladyRole = soladyTarget.ROLE();

        vm.prank(admin);
        libsolManager.setUserRole(newUser, ROLE, true);
        vm.snapshotGasLastFrame("AuthManager", "grant role / libsol");

        vm.prank(admin);
        ozManager.grantRole(ROLE, newUser, 0);
        vm.snapshotGasLastFrame("AuthManager", "grant role / OpenZeppelin");

        vm.prank(admin);
        soladyTarget.grantRoles(newUser, soladyRole);
        vm.snapshotGasLastFrame("AuthManager", "grant role / Solady OwnableRoles");
    }
}
