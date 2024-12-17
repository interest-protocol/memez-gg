module recrd::recrd_migrator;

use cetus_clmm::{config::GlobalConfig, factory::Pools, pool_creator::create_pool_v2};
use memez_acl::acl::AuthWitness;
use memez_fun::memez_fun::MemezMigrator;
use recrd::recrd_version::CurrentVersion;
use sui::{clock::Clock, coin::{Coin, CoinMetadata}, sui::SUI};

// === Constants ===

const DEAD_ADDRESS: address = @0x0;

// https://cetus-1.gitbook.io/cetus-developer-docs/developer/via-contract/features-available/create-pool
const INITIAL_TICK_SPACING: u32 = 200;

// ~ 2^32 - 443636
const INITIAL_TICK_LOWER_IDX: u32 = 4294523696;

// ~ Almost the max tick index
// https://github.com/CetusProtocol/cetus-clmm-sui-sdk/blob/main/src/types/constants.ts#L7
const INITIAL_TICK_UPPER_IDX: u32 = 443630;

// @dev Refer to https://github.com/interest-protocol/memez.gg-sdk/blob/main/src/scripts/memez/cetus-price.ts
// This means that 1 Meme coin equals to 0.000012 Sui.
const INITIALIZE_PRICE: u128 = 63901395939770060;

// === Structs ===

public struct Witness() has drop;

public struct RecrdConfig has key {
    id: UID,
    tick_spacing: u32,
    initialize_price: u128,
    tick_lower_idx: u32,
    tick_upper_idx: u32,
    treasury: address,
}

// === Initializer ===

fun init(ctx: &mut TxContext) {
    let recrd = RecrdConfig {
        id: object::new(ctx),
        tick_spacing: INITIAL_TICK_SPACING,
        initialize_price: INITIALIZE_PRICE,
        tick_lower_idx: INITIAL_TICK_LOWER_IDX,
        tick_upper_idx: INITIAL_TICK_UPPER_IDX,
        treasury: @treasury,
    };

    transfer::share_object(recrd);
}

// === Public Mutative Functions ===

public fun migrate<Meme>(
    config: &mut RecrdConfig,
    clock: &Clock,
    cetus_config: &GlobalConfig,
    cetus_pools: &mut Pools,
    sui_metadata: &CoinMetadata<SUI>,
    meme_metadata: &CoinMetadata<Meme>,
    migrator: MemezMigrator<Meme>,
    version: &CurrentVersion,
    ctx: &mut TxContext,
) {
    version.assert_is_valid();

    let (sui_balance, meme_balance) = migrator.destroy(Witness());

    let (position, excess_meme, excess_sui) = create_pool_v2(
        cetus_config,
        cetus_pools,
        config.tick_spacing,
        config.initialize_price,
        b"".to_string(),
        config.tick_lower_idx,
        config.tick_upper_idx,
        meme_balance.into_coin(ctx),
        sui_balance.into_coin(ctx),
        meme_metadata,
        sui_metadata,
        false,
        clock,
        ctx,
    );

    transfer::public_transfer(position, DEAD_ADDRESS);

    transfer_or_burn(excess_meme, DEAD_ADDRESS);
    transfer_or_burn(excess_sui, config.treasury);
}

// === Admin Functions ===

public fun set_tick_spacing(self: &mut RecrdConfig, _: &AuthWitness, tick_spacing: u32) {
    self.tick_spacing = tick_spacing;
}

public fun set_initialize_price(self: &mut RecrdConfig, _: &AuthWitness, initialize_price: u128) {
    self.initialize_price = initialize_price;
}

public fun set_tick_range(
    self: &mut RecrdConfig,
    _: &AuthWitness,
    tick_lower_idx: u32,
    tick_upper_idx: u32,
) {
    self.tick_lower_idx = tick_lower_idx;
    self.tick_upper_idx = tick_upper_idx;
}

// === Private Functions ===

fun transfer_or_burn<CoinType>(coin: Coin<CoinType>, to: address) {
    if (coin.value() == 0) {
        coin.destroy_zero();
    } else {
        transfer::public_transfer(coin, to);
    }
}
