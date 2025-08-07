
module bluefin_helper::bluefin_helper;

use bluefin_spot::{config::GlobalConfig, pool};
use sui::{
    clock::Clock,
    coin::{Coin, CoinMetadata},
    sui::SUI,
    url
};

// === Constants ===

const DEAD_ADDRESS: address = @0x0;

// https://cetus-1.gitbook.io/cetus-developer-docs/developer/via-contract/features-available/create-pool
const TICK_SPACING: u32 = 200;

const FEE_RATE: u64 = 10000;

// @dev Refer to https://github.com/interest-protocol/memez.gg-sdk/blob/main/src/scripts/memez/cetus-price.ts
// This means that 1 Meme coin equals to 0.000012 Sui.
const INITIALIZE_PRICE: u128 = 63901395939770060;

const MIN_TICK: u32 = 4294523696;

const MAX_TICK: u32 = 443600;

// === Public Mutative Functions ===

public fun new_pool<Meme, CoinTypeFee>(
    bluefin_config: &mut GlobalConfig,
    clock: &Clock,
    sui_metadata: &CoinMetadata<SUI>,
    meme_metadata: &CoinMetadata<Meme>,
    sui_coin: Coin<SUI>,
    meme_coin: Coin<Meme>,
    fee: Coin<CoinTypeFee>,
    ctx: &mut TxContext,
) {
    let sui_balance_value = sui_coin.value();

    let (
        _,
        position,
        _,
        _,
        excess_meme,
        excess_sui,
    ) = pool::create_pool_with_liquidity<Meme, SUI, CoinTypeFee>(
        clock,
        bluefin_config,
        x"",
        x"",
        meme_metadata.get_symbol().into_bytes(),
        meme_metadata.get_decimals(),
        meme_metadata
            .get_icon_url()
            .destroy_with_default(url::new_unsafe_from_bytes(x""))
            .inner_url()
            .into_bytes(),
        sui_metadata.get_symbol().into_bytes(),
        sui_metadata.get_decimals(),
        sui_metadata
            .get_icon_url()
            .destroy_with_default(url::new_unsafe_from_bytes(x""))
            .inner_url()
            .into_bytes(),
        TICK_SPACING,
        FEE_RATE,
        INITIALIZE_PRICE,
        fee.into_balance(),
        MIN_TICK,
        MAX_TICK,
        meme_coin.into_balance(),
        sui_coin.into_balance(),
        sui_balance_value,
        false,
        ctx,
    );
    transfer::public_transfer(position, DEAD_ADDRESS); 
    transfer::public_transfer(excess_meme.into_coin(ctx), DEAD_ADDRESS);
    transfer::public_transfer(excess_sui.into_coin(ctx), DEAD_ADDRESS);

}