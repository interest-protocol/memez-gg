# MemezFun

A hybrid AMM (Automated Market Maker) implementation built on the Sui blockchain that enables meme token trading without requiring initial quote token liquidity, powered by virtual liquidity mechanics.

## Overview

MemezFun implements different AMM mechanisms for each launch mode:

-   Pump Mode: Constant product AMM (x \* y = k) with price impact protection
-   Auction Mode: Constant sum AMM for linear price discovery
-   Stable Mode: Constant sum AMM for price stability
-   Token bonding curve mechanics
-   Liquidity provision and management
-   Token migration capabilities
-   Auction-based price discovery

## Launch Modes

The protocol supports three distinct launch modes for meme token distribution:

### Pump Mode

-   Uses constant product bonding curve (k = x \* y)
-   Floor price set by the pool creator via virtual liquidity
-   Dynamic burn tax based on price impact of meme coin sales
-   Allows deployer to be first buyer in the pool
-   Developer can only claim coins after bonding
-   Supports Token standard to prevent premature DEX pool creation

### Auction Mode

-   Implements dutch auction mechanism using constant sum AMM
-   Price decreases linearly over 30 minutes
-   Protocol provides liquidity linearly to the pool
-   Initial auction price and floor price set by protocol admin
-   Deployer receives percentage of meme coin supply after migration
-   Traders can influence bonding market
-   Developer can only claim coins after bonding

### Stable Mode

-   Uses constant sum AMM to provide constant price for buying/selling
-   Safest option for users
-   Deployer can choose allocation and vesting period
-   Developer can only claim coins after bonding
-   Supports Token standard to prevent premature DEX pool creation

## Modules

The protocol consists of several key components:

-   `memez_fun.move`: Core functions for the different pool implementations
-   `pump.move`: Constant product bonding pool
-   `auction.move`: Auction-based price discovery pool
-   `stable.move`: Constant sum pool
-   `events.move`: AMM event tracking
-   `config.move`: Pool configuration management
-   `errors.move`: AMM-specific error handling

## Installing

### [Move Registry CLI](https://docs.suins.io/move-registry)

```bash
# testnet
mvr add @interest/memez-fun --network testnet

# mainnet
mvr add @interest/memez-fun --network mainnet
```

### Manual

To add this library to your project, add this to your `Move.toml`.

```toml
# goes into [dependencies] section
memez_fun = { r.mvr = "@interest/memez-fun" }

# add this section to your Move.toml
[r.mvr]
network = "mainnet"
```

### Package Ids

MemezFun is deployed on Sui Network mainnet at: [0x...] (pending deployment)

It is deployed on Sui Network testnet at: [0xcad2e05e9771c6b1aad35d4f3df42094d5d49effc2a839e34f37ae31dc373fe7](https://suiscan.xyz/testnet/object/0xcad2e05e9771c6b1aad35d4f3df42094d5d49effc2a839e34f37ae31dc373fe7/contractst)

### Testing

```bash
sui move test
```

## API Reference

### Core AMM Functions

-   **Pool Creation**: Create new liquidity pools with configurable parameters
-   **Token Swaps**: Execute token swaps with slippage protection
-   **Liquidity Management**: Add/remove liquidity with fee calculations
-   **Price Discovery**: Implement various price discovery mechanisms

### Launch Mode Specific Functions

#### Pump Mode

-   **Virtual Liquidity**: Set and manage virtual liquidity for floor price
-   **Bonding Curve**: Implement constant product bonding curve mechanics
-   **Migration**: Handle pool migration to DEX

#### Auction Mode

-   **Price Decay**: Manage linear price decay over time
-   **Liquidity Provision**: Control protocol liquidity provision
-   **Auction Parameters**: Configure auction duration and parameters

#### Stable Mode

-   **Price Stability**: Maintain constant price mechanism
-   **Vesting**: Manage token vesting schedules
-   **Allocation**: Handle deployer token allocation

## Security

This is a beta version of the constant product AMM implementation. Use at your own risk and always verify the code before interacting with the protocol.

## Disclaimer

This is provided on an "as is" and "as available" basis. We do not give any warranties and will not be liable for any loss incurred through any use of this codebase.

While MemezFun has been tested, there may be parts that may exhibit unexpected emergent behavior when used with other code, or may break in future Move versions.

Please always include your own thorough tests when using MemezFun to make sure it works correctly with your code.

## License

This project is licensed under the Apache-2.0 License.

## Author

Jose Cerqueira (jose@interestprotocol.com)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
