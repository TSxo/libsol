# libsol

[![CI](https://github.com/TSxo/libsol/actions/workflows/ci.yaml/badge.svg)](https://github.com/TSxo/libsol/actions/workflows/ci.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](https://opensource.org/licenses/MIT)

Gas-optimized Solidity modules for access control, pausing, reentrancy guards,
rate limiting, and upgradeable proxies. Modules that keep state use namespaced
storage (ERC-7201 slots, the EIP-1967 slots for proxies, or transient storage
for `MutexTransient`), so they can sit behind a proxy. They do their work in
inline assembly. Every module with non-trivial assembly is checked against a
plain-Solidity reference in differential tests.

libsol is a research library and has not been audited. Read the
[Disclaimer](#disclaimer) before using it.

## Modules

```text
src
├── auth
│   ├── Owned                   ERC-173 single-owner access control
│   ├── Owned2Step              Owned, where the new owner must accept
│   └── managed
│       ├── AuthManager         Central authority with 254 roles and per-function rules
│       └── AuthManaged         Adds an auth modifier that asks an AuthManager
├── pause
│   ├── Pausable                Local pause switch with notPaused and paused modifiers
│   └── managed
│       ├── PauseManager        Central pause authority, per target or global
│       └── PauseManaged        Adds a notPaused modifier that asks a PauseManager
├── proxy
│   ├── CallContext             onlyProxy and notDelegated modifiers
│   ├── Initializable           Initializer guards for contracts behind a proxy
│   ├── Proxy                   Delegation core
│   ├── ERC1967
│   │   └── ERC1967             ERC-1967 slots, with helpers to read and change them
│   ├── UUPS
│   │   ├── ERC1822             proxiableUUID check that UUPS upgrades must pass
│   │   ├── UUPSImplementation  UUPS implementation base with upgradeToAndCall
│   │   └── UUPSProxy           ERC-1967 proxy for UUPS implementations
│   └── beacon
│       ├── BeaconProxy         Asks its beacon for the implementation on every call
│       └── UpgradeableBeacon   Owned beacon that upgrades every proxy at once
└── utils
    ├── Mutex                   Reentrancy guard in storage
    ├── MutexTransient          Reentrancy guard in transient storage (EIP-1153)
    └── RateLimiter             Token buckets that cap consumption over time
```

The auth, pause, beacon, and rate limiter modules each have an `I*` interface
alongside them, with their events and errors.

## Usage

Install with Foundry and add a remapping:

```bash
forge install TSxo/libsol
```

```text
@tsxo/libsol/=lib/libsol/src/
```

There are no tagged releases yet, so pin the commit you install.

The library needs Solidity 0.8.24 or later, and CI builds `src/` with 0.8.24 to
check that. The pragma does not set the EVM version. On a chain without
transient storage, compile for an earlier EVM (for example
`evm_version = "shanghai"`) and use `Mutex` rather than `MutexTransient`.

### Owned

```solidity
import { Owned } from "@tsxo/libsol/auth/Owned.sol";

contract Vault is Owned {
    constructor(address owner_) {
        _initializeOwned(owner_);
    }

    function sweep() external onlyOwner { /* ... */ }
}
```

### Owned2Step

```solidity
import { Owned2Step } from "@tsxo/libsol/auth/Owned2Step.sol";

contract Vault is Owned2Step {
    constructor(address owner_) {
        _initializeOwned(owner_);
    }
}

// vault.transferOwnership(newOwner);   // as the owner: proposes
// vault.acceptOwnership();             // as newOwner: completes
```

`transferOwnership(address(0))` cancels a pending transfer. Use
`renounceOwnership` to give up ownership.

### AuthManager and AuthManaged

```solidity
import { Owned } from "@tsxo/libsol/auth/Owned.sol";
import { AuthManager } from "@tsxo/libsol/auth/managed/AuthManager.sol";
import { AuthManaged } from "@tsxo/libsol/auth/managed/AuthManaged.sol";

// You choose who may manage the Authority; here, a single owner.
contract Authority is Owned, AuthManager {
    constructor(address owner_) {
        _initializeOwned(owner_);
    }

    function _authorizeManager() internal view override onlyOwner { }
}

contract Treasury is AuthManaged {
    constructor(address authority) {
        _initializeAuthManaged(authority);
    }

    function withdraw(uint256 amount) external auth { /* ... */ }
}

// As the Authority's owner:
// authority.setUserRole(alice, 1, true);
// authority.setRoleAccess(address(treasury), Treasury.withdraw.selector, 1, true);
```

### Pausable, PauseManager, and PauseManaged

```solidity
import { Pausable } from "@tsxo/libsol/pause/Pausable.sol";

contract Market is Pausable {
    function trade() external notPaused { /* ... */ }

    function quote() external view notPaused returns (uint256) { /* ... */ }
}
```

`PauseManager` and `PauseManaged` work like `AuthManager` and `AuthManaged`. One
manager, guarded by your `_authorizeManager` rule, pauses any number of targets,
one at a time or all at once.

### Mutex and MutexTransient

```solidity
import { MutexTransient } from "@tsxo/libsol/utils/MutexTransient.sol";

contract Pool is MutexTransient {
    function deposit() external lock { /* ... */ }

    function totalAssets() external view whenUnlocked returns (uint256) { /* ... */ }
}
```

Use `Mutex` on chains without transient storage. It needs `_initializeMutex()`
in the constructor or initializer. Both raise the same `Mutex__Locked()` error.

### RateLimiter

```solidity
import { RateLimiter } from "@tsxo/libsol/utils/RateLimiter.sol";

contract Bridge is RateLimiter {
    bytes32 constant WITHDRAWALS = keccak256("withdrawals");

    constructor() {
        // At most 1,000 tokens at once, refilling at 1 token per second.
        _setRateLimit(WITHDRAWALS, 1_000e18, 1e18);
    }

    function withdraw(uint256 amount) external {
        _consume(WITHDRAWALS, amount); // reverts with RateLimiter__Exceeded()
        /* ... */
    }
}
```

`_setRateLimit` has no access control of its own, so guard any external function
that calls it.

### UUPS Proxy and Initializable

```solidity
import { Owned } from "@tsxo/libsol/auth/Owned.sol";
import { Initializable } from "@tsxo/libsol/proxy/Initializable.sol";
import { UUPSImplementation } from "@tsxo/libsol/proxy/UUPS/UUPSImplementation.sol";
import { UUPSProxy } from "@tsxo/libsol/proxy/UUPS/UUPSProxy.sol";

contract TokenV1 is UUPSImplementation, Owned, Initializable {
    constructor() {
        _disableInitializers(); // nobody can initialize the implementation
    }

    function initialize(address owner_) external initializer {
        _initializeOwned(owner_);
    }

    function _authorizeUpgrade(address) internal override onlyOwner { }
}

// new UUPSProxy(address(new TokenV1()), abi.encodeCall(TokenV1.initialize, (owner)));
```

A later version can run a one-off migration with `reinitializer(2)`.

### Beacon Proxy

```solidity
import { BeaconProxy } from "@tsxo/libsol/proxy/beacon/BeaconProxy.sol";
import { UpgradeableBeacon } from "@tsxo/libsol/proxy/beacon/UpgradeableBeacon.sol";

// Vault is an Initializable implementation, as above, without UUPS.
UpgradeableBeacon beacon = new UpgradeableBeacon(owner, address(new Vault()));

new BeaconProxy(address(beacon), abi.encodeCall(Vault.initialize, (alice)));
new BeaconProxy(address(beacon), abi.encodeCall(Vault.initialize, (bob)));

// As the owner, upgrade both vaults at once:
// beacon.upgradeTo(address(new VaultV2()));
```

A proxy's beacon is fixed at construction. Whoever owns the beacon controls the
code of every proxy that uses it.

## Gas

The benchmarks in [`test/gas/`](test/gas) measure each module next to its
OpenZeppelin Contracts v5.7.0 and Solady v0.1.26 counterpart. The results are
committed in [`snapshots/`](snapshots), and CI fails if they change. Run
`just bench-table` to print them, or `just bench-snapshot` to regenerate them.

They are measured with solc 0.8.39, the optimizer on at 200 runs, and the osaka
EVM. `forge test --isolate` runs each state-changing call as its own
transaction, so those figures include the 21,000 base cost. 

Some comparisons are not like for like:

- **Owned2Step.** Solady's handover runs the other way round, and its request
  skips the owner check.
- **Mutex.** Solady's storage guard pays for a fresh write on its first lock.
  Its transient guard is set to transient storage on every chain with its
  `_useTransientReentrancyGuardOnlyOnMainnet` hook.
- **Proxies.** Solady's are minimal `LibClone` bytecode, and its beacon proxy
  reads the beacon from storage on every call.
- **ERC1967.** libsol's proxy and `upgradeToAndCall` share one upgrade path,
  which costs a little more than separate inline copies.
- **Role-based access.** `AccessManager` adds delays, scheduling, and guardians,
  and `OwnableRoles` keeps roles in the target, so both are reference points.
- **Pausable and RateLimiter.** Solady has no pause module, and neither library
  has a rate limiter.

## Testing

- **Unit tests** in `test/unit/` cover each module's behaviour, reverts, and
  events, and check every hard-coded storage slot and selector.
- **Differential tests** in `test/differential/` run each assembly module and a
  plain-Solidity reference through the same fuzzed sequences of calls, including
  malformed authorities, beacons, and implementations, and require identical
  results.
- **Invariant tests** in `test/invariant/` check that `RateLimiter` never
  releases more than its limits allow while Forge moves time forward between
  calls. It is the only module whose state builds up across calls.
- **Symbolic checks** in `test/symbolic/` prove `AuthManager`'s bitmask rules,
  `Initializable`'s guards, and the authority reply checks for every input.
- **Brutalization.** Every harness in `test/harness/` passes arguments on with
  junk in their unused bits, using Solady's `Brutalizer`.
  `forge test --brutalize` reruns the suites with Forge's own dirtying of casts
  and memory, but it does not dirty arguments, so both are used.
- **Gas benchmarks** in `test/gas/` are checked against `snapshots/` in CI.

## Development

```bash
just              # list recipes
just qc           # format, build, lint, tests, brutalized tests, and gas check
just symbolic     # symbolic checks (needs z3)
just mutate       # mutation testing over src/ (slow, and advisory)
just coverage     # HTML coverage report for src/ in .local/coverage/
just analysis     # advisory Slither reports in .local/slither/
just bench-check  # gas benchmarks against snapshots/
```

The Nix dev shell (`nix develop`) provides just, jq, z3, lcov, and Slither.
Foundry comes from your PATH, and CI pins Forge v1.10.0. Run `just doctor` to
see the versions in use.

## Disclaimer

libsol is unaudited and provided as-is, without warranty. See
[LICENSE](LICENSE). It is optimized for gas, which means inline assembly and few
defensive checks beyond those listed below. Its contracts assume integrators
uphold these invariants:

1. **Initialization runs once.** The `_initialize*` functions do not guard
   against being called again. Call them from a constructor, or, behind a proxy,
   from an `initializer` function (see `Initializable`).
2. **`auth` guards external entry points only.** Access is decided by the
   selector the call entered with, so do not apply it to internal functions, to
   `receive` or `fallback`, or to public functions that are also called
   internally. `notPaused` does not look at the selector: it asks only whether
   the target is paused.
3. **Managers are guarded by your rule.** `AuthManager` and `PauseManager` call
   `_authorizeManager` before every change. The inheriting contract must
   implement it, and whoever passes it controls every permission or pause.
4. **Authorities are trusted.** An Authority or Pause Authority decides every
   guarded call on its targets, and a reverting one blocks them. Both must be
   contracts, and libsol rejects accounts without code.
5. **`Owned` transfers ownership in one step.** Its
   `transferOwnership(address(0))` renounces ownership permanently. Use
   `Owned2Step` if the new owner should have to accept.
6. **Roles run from 0 to 253.** Bits 254 and 255 of an access bitmask are the
   public and closed flags, and closed takes precedence over public.
7. **UUPS implementations restrict upgrades.** `_authorizeUpgrade` must apply
   access control. The `ERC1967` helpers, including `_changeAdmin` and
   `_upgradeBeaconToAndCall`, have none of their own, and `Proxy` forwards every
   call with no admin functions. ETH sent to `upgradeToAndCall` with empty
   `data` stays in the proxy.
8. **Guarded functions cannot call each other.** Compose them through internal
   functions behind a single `lock`.

Patterns here draw on [Solmate](https://github.com/transmissions11/solmate),
[OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts), and
[Solady](https://github.com/Vectorized/solady). Thank you to their authors.

## License

MIT. See [LICENSE](LICENSE).

