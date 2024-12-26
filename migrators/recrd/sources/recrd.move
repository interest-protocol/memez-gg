module recrd::recrd_migrator;

use cetus_clmm::{
    config::GlobalConfig,
    factory::Pools,
    pool::{Self, Pool},
    pool_creator::create_pool_v2
};
use ipx_coin_standard::ipx_coin_standard::IPXTreasuryStandard;
use memez_acl::acl::AuthWitness;
use memez_fun::memez_fun::MemezMigrator;
use recrd::recrd_version::CurrentVersion;
use std::type_name::{Self, TypeName};
use sui::{clock::Clock, coin::{Coin, CoinMetadata}, event::emit, sui::SUI};

// === Constants ===

const DEAD_ADDRESS: address = @0x0;

// https://cetus-1.gitbook.io/cetus-developer-docs/developer/via-contract/features-available/create-pool
const TICK_SPACING: u32 = 200;

// @dev Refer to https://github.com/interest-protocol/memez.gg-sdk/blob/main/src/scripts/memez/cetus-price.ts
// This means that 1 Meme coin equals to 0.000012 Sui.
const INITIALIZE_PRICE: u128 = 63901395939770060;

const MIN_TICK: u32 = 4294523696;

const MAX_TICK: u32 = 443600;

const MEME_DECIMALS: u8 = 9;

const MEME_TOTAL_SUPPLY: u64 = 1_000_000_000_000_000_000;

// === Errors ===

const EInvalidTickSpacing: u64 = 0;

const EInvalidDecimals: u64 = 1;

const EInvalidTotalSupply: u64 = 2;

// === Structs ===

public struct Witness() has drop;

public struct RecrdConfig has key {
    id: UID,
    initialize_price: u128,
    treasury: address,
}

// === Events ===

public struct NewPool has copy, drop {
    pool: address,
    tick_spacing: u32,
    meme: TypeName,
    sui_balance: u64,
    meme_balance: u64,
}

// === Initializer ===

fun init(ctx: &mut TxContext) {
    let recrd = RecrdConfig {
        id: object::new(ctx),
        initialize_price: INITIALIZE_PRICE,
        treasury: @treasury,
    };

    transfer::share_object(recrd);
}

// === Public Mutative Functions ===

public fun migrate_to_new_pool<Meme>(
    config: &mut RecrdConfig,
    clock: &Clock,
    ipx_treasury: &IPXTreasuryStandard,
    cetus_config: &GlobalConfig,
    cetus_pools: &mut Pools,
    sui_metadata: &CoinMetadata<SUI>,
    meme_metadata: &CoinMetadata<Meme>,
    migrator: MemezMigrator<Meme>,
    version: &CurrentVersion,
    ctx: &mut TxContext,
) {
    version.assert_is_valid();

    assert!(meme_metadata.get_decimals() == MEME_DECIMALS, EInvalidDecimals);
    assert!(ipx_treasury.total_supply<Meme>() == MEME_TOTAL_SUPPLY, EInvalidTotalSupply);

    let (sui_balance, meme_balance) = migrator.destroy(Witness());

    let sui_balance_value = sui_balance.value();
    let meme_balance_value = meme_balance.value();

    let (position, excess_meme, excess_sui) = create_pool_v2(
        cetus_config,
        cetus_pools,
        TICK_SPACING,
        config.initialize_price,
        b"".to_string(),
        MIN_TICK,
        MAX_TICK,
        meme_balance.into_coin(ctx),
        sui_balance.into_coin(ctx),
        meme_metadata,
        sui_metadata,
        false,
        clock,
        ctx,
    );

    emit(NewPool {
        pool: position.pool_id().to_address(),
        tick_spacing: TICK_SPACING,
        meme: type_name::get<Meme>(),
        sui_balance: sui_balance_value,
        meme_balance: meme_balance_value,
    });

    transfer::public_transfer(position, DEAD_ADDRESS);

    transfer_or_burn(excess_meme, DEAD_ADDRESS);
    transfer_or_burn(excess_sui, config.treasury);
}

// @dev We do not need to check decimals nor total supply here because we do not set the initial price.
public fun migrate_to_existing_pool<Meme>(
    config: &mut RecrdConfig,
    clock: &Clock,
    cetus_config: &GlobalConfig,
    pool: &mut Pool<Meme, SUI>,
    migrator: MemezMigrator<Meme>,
    version: &CurrentVersion,
    ctx: &mut TxContext,
) {
    version.assert_is_valid();

    assert!(pool.tick_spacing() == TICK_SPACING, EInvalidTickSpacing);

    let (mut sui_balance, mut meme_balance) = migrator.destroy(Witness());

    let mut position = pool::open_position(cetus_config, pool, MIN_TICK, MAX_TICK, ctx);

    let meme_balance_value = meme_balance.value();
    let sui_balance_value = sui_balance.value();

    let receipt = pool::add_liquidity_fix_coin(
        cetus_config,
        pool,
        &mut position,
        meme_balance_value,
        false,
        clock,
    );

    let (amount_a, amount_b) = receipt.add_liquidity_pay_amount();

    let excess_meme = meme_balance.split(meme_balance_value.min(amount_a)).into_coin(ctx);
    let excess_sui = sui_balance.split(sui_balance_value.min(amount_b)).into_coin(ctx);

    pool::repay_add_liquidity(cetus_config, pool, meme_balance, sui_balance, receipt);

    emit(NewPool {
        pool: position.pool_id().to_address(),
        tick_spacing: TICK_SPACING,
        meme: type_name::get<Meme>(),
        sui_balance: sui_balance_value,
        meme_balance: meme_balance_value,
    });

    transfer::public_transfer(position, DEAD_ADDRESS);
    transfer_or_burn(excess_meme, DEAD_ADDRESS);
    transfer_or_burn(excess_sui, config.treasury);
}

// === Admin Functions ===

public fun set_initialize_price(self: &mut RecrdConfig, _: &AuthWitness, initialize_price: u128) {
    self.initialize_price = initialize_price;
}

// === Private Functions ===

fun transfer_or_burn<CoinType>(coin: Coin<CoinType>, to: address) {
    if (coin.value() == 0) {
        coin.destroy_zero();
    } else {
        transfer::public_transfer(coin, to);
    }
}
