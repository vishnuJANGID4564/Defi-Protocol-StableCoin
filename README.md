
## Architecture of the StableCoin
1. Anchored or Pegged to USD 
    1. Chainlink price feed.
    2. set a function to exchange ETH and BTC -> $$$( thier $ equivalent )
2. Stablilty Mechanism : Algorithmic (DEcentralised)
    1. people can only mint the SC if they have enough collateral to pay (OVER- Collateralized)
3. Collateral type: Exogenous(Crypto)
    1. wETH 
        1. Wrapped ETH (wETH) is an ERC-20 token that represents ETH and is pegged 1:1 to the value of ETH. It can be used to interact with DeFi protocols and applications whereas ETH, by itself, can not be used in many dApps
        2. Remember, there is no difference in value between WETH and ETH. The only differences are in how they are used. In short, WETH is a more flexible and user-friendly version of ETH that can be used for a broader range of purposes.
    2. wBTC
        1. Bitcoin operates on its blockchain, while WBTC is built on the Ethereum blockchain. Token Format: Bitcoin is a native cryptocurrency, while WBTC is an ERC-20 token.





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

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
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
