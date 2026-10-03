## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

Contract publication is operated from [evx-deploy](https://github.com/evx-finance/evx-deploy). This repository keeps the Foundry implementations (`Deploy.s.sol`, `DeployWeth9.s.sol`, `DeployFixtureTokens.s.sol`); they are invoked only through that registry.

```shell
python3 -m evx_deploy plan --network anvil
python3 -m evx_deploy deploy --network anvil
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```


TODO: Merge libraries AddressStringUtil with/into StringUtils