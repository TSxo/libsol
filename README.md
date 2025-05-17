# libsol

[![CI](https://github.com/TSxo/libsol/actions/workflows/test.yml/badge.svg)](https://github.com/TSxo/libsol/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](https://opensource.org/licenses/MIT)

A suite of opinionated, optimized smart contract modules.

## Contracts

The smart contracts are located in the `src` directory.

```
.
├── auth
│   ├── IOwned.sol
│   ├── managed
│   │   ├── AuthManaged.sol
│   │   ├── AuthManager.sol
│   │   ├── IAuthManaged.sol
│   │   ├── IAuthManager.sol
│   │   └── IAuthority.sol
│   └── Owned.sol
├── mixins
│   ├── CallContext.sol
│   └── Mutex.sol
├── pause
│   ├── IPausable.sol
│   ├── managed
│   │   ├── IPauseAuthority.sol
│   │   ├── IPauseManaged.sol
│   │   ├── IPauseManager.sol
│   │   ├── PauseManaged.sol
│   │   └── PauseManager.sol
│   └── Pausable.sol
└── proxy
    ├── ERC1967
    │   └── ERC1967Logic.sol
    ├── Proxy.sol
    └── UUPS
        ├── UUPSImplementation.sol
        └── UUPSProxy.sol

```

## Purpose & License

This project is primarily for research purposes. It is licensed under MIT, and
you are free to use the code however you wish. Please be sure to carefully note
the disclaimer section below.

Many of the patterns implemented in this repository are well-known and
popularized by established projects in the ecosystem. My thanks and appreciation
to the many developers whose work has influenced this project.

Notably, heavy inspiration is taken from:

- [Solmate](https://github.com/transmissions11/solmate)
- [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts)
- [Solady](https://github.com/Vectorized/solady)

This project is under active development. New modules and features will be added
to enhance functionality and performance.

Contributions and suggestions are welcome.

## Disclaimer

This suite of contracts prioritize an opinionated balance of optimization and
readability. **They were not designed with user safety in mind** and contain
minimal safety checks. It is experimental software and is provided **as-is**,
without any warranties or guarantees of functionality, security, or fitness
for any particular purpose.

There are implicit invariants these contracts expect to hold. Users and
developers integrating this contract **do so at their own risk** and are
responsible for thoroughly reviewing the code before use.

The author assumes **no liability** for any loss, damage, or unintended
behavior resulting from the use, deployment, or interaction with this contract.
