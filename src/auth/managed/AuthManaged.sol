// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IAuthManaged } from "./IAuthManaged.sol";
import { IAuthority } from "./IAuthority.sol";

/// @title AuthManaged
///
/// @author TSxo
///
/// @dev This contract provides an `auth` modifier. Functions in the inheriting
/// contract that apply this modifier will have their access controlled according
/// to an "Authority". An Authority is any contract that implements the `IAuthority`
/// interface - such as `AuthManager`.
///
/// The Authority is set during initialization and updatable only by the current
/// Authority.
///
/// # Upgrade Compatible
///
/// This contract utilizes ERC-7201 namespaced storage, making it compatible with
/// upgradeable contract architectures. Note, it does not enforce any restrictions
/// against reinitialization, leaving such protection mechanisms up to the
/// inheriting contract.
///
/// # Important
///
/// Because access is ultimately determined by the function that entered the
/// contract, it is crucial that the `auth` modifier be applied to functions
/// very carefully.
///
/// In general, it should only be applied to functions that serve as external
/// entry points into the contract. It should not be applied to:
/// - Public functions that are accessed internally.
/// - Internal or private functions.
/// - `receive` or `fallback` functions.
///
/// Instead, favour function composition to ensure proper access control. Failure
/// to follow these rules can lead to critical security issues.
///
/// # Disclaimer
///
/// This contract prioritizes an opinionated balance between optimization and
/// readability. **It was not designed with user safety in mind** and contains
/// minimal safety checks. It is experimental software and is provided **as-is**,
/// without any warranties or guarantees of functionality, security, or fitness
/// for any particular purpose.
///
/// There are implicit invariants this contract expects to hold. Users and
/// developers integrating this contract **do so at their own risk** and are
/// responsible for thoroughly reviewing the code before use.
///
/// The author assumes **no liability** for any loss, damage, or unintended
/// behavior resulting from the use, deployment, or interaction with this contract.
///
/// # Acknowledgements
///
/// Heavy inspiration is taken from:
/// - Open Zeppelin;
/// - Solmate; and
/// - Solady.
///
/// Thank you.
abstract contract AuthManaged is IAuthManaged {
    // -------------------------------------------------------------------------
    // Type Declarations

    /// @custom:storage-location erc7201:libsol.storage.AuthManaged
    struct AuthManagedStorage {
        IAuthority authority;
    }

    // -------------------------------------------------------------------------
    // State

    /// keccak256(abi.encode(uint256(keccak256("libsol.storage.AuthManaged")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant STORAGE = 0xba07b3ca0f769fbcf052f5eef32e58c07f3aeeec01c8167517b7043932526600;

    /// @dev `keccak256(bytes("AuthorityUpdated(address,address)"))`.
    bytes32 private constant AUTHORITY_UPDATED = 0xa3396fd7f6e0a21b50e5089d2da70d5ac0a3bbbd1f617a93f134b76389980198;

    // -------------------------------------------------------------------------
    // Modifiers

    /// @dev Restricts access according to the rules of the Authority.
    ///
    /// Because access is ultimately determined by the function that entered the
    /// contract, it is crucial that the `auth` modifier be applied to functions
    /// very carefully.
    ///
    /// In general, it should only be applied to functions that serve as external
    /// entry points into the contract. It should not be applied to:
    /// - Public functions that are accessed internally.
    /// - Internal or private functions.
    /// - `receive` or `fallback` functions.
    ///
    /// Instead, favour function composition to ensure proper access control.
    /// Failure to follow these rules can lead to critical security issues.
    modifier auth() virtual {
        _assertAuthorized(msg.sender, msg.sig);
        _;
    }

    // -------------------------------------------------------------------------
    // Functions - Init

    /// @notice Initializes the contract by setting the initial Authority.
    ///
    /// @param initialAuthority The address to be set as the initial Authority.
    function _initializeAuthManaged(address initialAuthority) internal virtual {
        _setAuthority(initialAuthority);
    }

    // -------------------------------------------------------------------------
    // Functions - Public

    /// @inheritdoc IAuthManaged
    function setAuthority(address newAuthority) public virtual {
        assembly ("memory-safe") {
            if iszero(eq(caller(), sload(STORAGE))) {
                mstore(0x00, 0x3583568e) // `AuthManaged__Unauthorized()`
                revert(0x1c, 0x04)
            }
        }

        _setAuthority(newAuthority);
    }

    /// @inheritdoc IAuthManaged
    function authority() public view virtual returns (address result) {
        assembly ("memory-safe") {
            result := sload(STORAGE)
        }
    }

    // -------------------------------------------------------------------------
    // Functions - Internal

    /// @notice Updates the contract's Authority.
    ///
    /// @param newAuthority The address of the new Authority.
    ///
    /// @dev Internal function with no access control or restriction regarding
    /// the address that can be set.
    ///
    /// Emits an `AuthorityUpdated` event.
    function _setAuthority(address newAuthority) internal virtual {
        assembly ("memory-safe") {
            log3(0, 0, AUTHORITY_UPDATED, sload(STORAGE), newAuthority)
            sstore(STORAGE, newAuthority)
        }
    }

    /// @notice Asserts that an account has the ability to call a function on this
    /// contract.
    ///
    /// @param user     The account that called the function.
    /// @param selector The selector of the called function.
    function _assertAuthorized(address user, bytes4 selector) internal view virtual {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            let manager := sload(STORAGE)

            mstore(ptr, shl(224, 0xb7009613)) // `canCall(address,address,bytes4)`
            mstore(add(ptr, 0x04), user)
            mstore(add(ptr, 0x24), address())
            mstore(add(ptr, 0x44), selector)

            mstore(0x40, add(ptr, 0x64))

            let success := staticcall(gas(), manager, ptr, 0x64, 0x00, 0x20)

            if iszero(eq(returndatasize(), 0x20)) { revert(0, 0) }
            if iszero(success) { revert(0, 0) }

            let result := mload(0x00)
            if iszero(result) {
                mstore(0x00, 0x3583568e) // `AuthManaged__Unauthorized()`
                revert(0x1c, 0x04)
            }
        }
    }
}
