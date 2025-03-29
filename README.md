# libsol

A suite of opinionated, optimized smart contract modules.

## Contracts

The smart contracts are located in the `src` directory.

```ml
auth
├── IOwned.sol
├── Owned.sol
└── managed
    ├── AuthManaged.sol
    ├── AuthManager.sol
    ├── IAuthManaged.sol
    ├── IAuthManager.sol
    └── IAuthority.sol
```

## Work in Progress

This project is currently under active development. New modules and features will
be added to enhance functionality and performance. While the core auth modules are
available for testing and experimentation, the complete suite will be published
once enough modules are integrated and thoroughly vetted.

Contributions and suggestions are welcomed.

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

## Acknowledgements

Heavy inspiration is taken from:

- [Solmate](https://github.com/transmissions11/solmate)
- [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts)
- [Solady](https://github.com/Vectorized/solady)

Thank you.
