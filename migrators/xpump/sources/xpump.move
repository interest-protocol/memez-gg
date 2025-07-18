module xpump_migrator::xpump_migrator;

use cetusclmm::{
    config::GlobalConfig,
    factory::{Self, Pools, PoolCreationCap},
    pool::Pool,
    pool_creator
};
use ipx_coin_standard::ipx_coin_standard::IPXTreasuryStandard;
use lpburn::lp_burn::{CetusLPBurnProof, BurnManager};
use memez_fun::memez_fun::MemezMigrator;
use std::type_name::{Self, TypeName};
use sui::{
    clock::Clock,
    coin::{Coin, CoinMetadata, TreasuryCap},
    dynamic_object_field as dof,
    event::emit,
    sui::SUI
};

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

const ONE_SUI: u64 = 1_000_000_000;

// === Errors ===

const EInvalidDecimals: u64 = 0;

const EInvalidTotalSupply: u64 = 1;

// === Structs ===

public struct Admin has key, store {
    id: UID,
}

public struct Witness() has drop;

public struct XPumpConfig has key {
    id: UID,
    initialize_price: u128,
    treasury: address,
    reward_value: u64,
}

public struct PoolCreationCapKey(TypeName) has copy, drop, store;

public struct LpBurnConfigKey(TypeName) has copy, drop, store;

// === Events ===

public struct NewPool has copy, drop {
    pool: address,
    tick_spacing: u32,
    meme: TypeName,
    sui_balance: u64,
    meme_balance: u64,
    burn_proof: address
}

public struct SetTreasury(address, address) has copy, drop;

public struct SetInitializePrice(u128, u128) has copy, drop;

public struct SetRewardValue(u64, u64) has copy, drop;

public struct CollectFee(address, u64, u64) has copy, drop;

// === Initializer ===

fun init(ctx: &mut TxContext) {
    let xpump_config = XPumpConfig {
        id: object::new(ctx),
        initialize_price: INITIALIZE_PRICE,
        treasury: @treasury,
        reward_value: ONE_SUI,
    };

    let admin = Admin {
        id: object::new(ctx),
    };

    transfer::share_object(xpump_config);
    transfer::public_transfer(admin, ctx.sender());
}

// === Public Mutative Functions ===

public fun register_pool<Meme>(
    config: &mut XPumpConfig,
    cetus_config: &GlobalConfig,
    cetus_pools: &mut Pools,
    meme_coin_treasury_cap: &mut TreasuryCap<Meme>,
    ctx: &mut TxContext,
) {
    let pool_creation_cap = factory::mint_pool_creation_cap(
        cetus_config,
        cetus_pools,
        meme_coin_treasury_cap,
        ctx,
    );

    factory::register_permission_pair<Meme, SUI>(
        cetus_config,
        cetus_pools,
        TICK_SPACING,
        &pool_creation_cap,
        ctx,
    );

    config.save_pool_creation_cap<Meme>(pool_creation_cap);
}

public fun migrate<Meme>(
    config: &mut XPumpConfig,
    burn_manager: &mut BurnManager,
    clock: &Clock,
    ipx_treasury: &IPXTreasuryStandard,
    cetus_config: &GlobalConfig,
    cetus_pools: &mut Pools,
    sui_metadata: &CoinMetadata<SUI>,
    meme_metadata: &CoinMetadata<Meme>,
    migrator: MemezMigrator<Meme, SUI>,
    ctx: &mut TxContext,
): Coin<SUI> {
    assert!(meme_metadata.get_decimals() == MEME_DECIMALS, EInvalidDecimals);
    assert!(ipx_treasury.total_supply<Meme>() == MEME_TOTAL_SUPPLY, EInvalidTotalSupply);

    let (meme_balance, mut sui_balance) = migrator.destroy(Witness());

    let reward = sui_balance.split(config.reward_value).into_coin(ctx);

    let pool_creation_cap = config.pool_creation_cap<Meme>();

    let sui_balance_value = sui_balance.value();
    let meme_balance_value = meme_balance.value();

    let (position, excess_meme, excess_sui) = pool_creator::create_pool_v2_with_creation_cap(
        cetus_config,
        cetus_pools,
        pool_creation_cap,
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

    let pool_id = position.pool_id();

    let burn_proof = burn_manager.burn_lp_v2(
        position,
        ctx,
    );

    emit(NewPool {
        pool: pool_id.to_address(),
        tick_spacing: TICK_SPACING,
        meme: type_name::get<Meme>(),
        sui_balance: sui_balance_value - excess_sui.value(),
        meme_balance: meme_balance_value - excess_meme.value(),
        burn_proof: object::id_address(&burn_proof),
    });

    config.save_lp_burn_proof<Meme>(burn_proof);

    transfer_or_burn(excess_meme, DEAD_ADDRESS);
    transfer_or_burn(excess_sui, config.treasury);

    reward
}

// === View Functions ===

public fun get_lp_burn_proof<Meme>(config: &XPumpConfig): &CetusLPBurnProof {
    dof::borrow<_, CetusLPBurnProof>(&config.id, LpBurnConfigKey(type_name::get<Meme>()))
}

// === Admin Functions ===

public fun set_initialize_price(self: &mut XPumpConfig, _: &Admin, initialize_price: u128) {
    assert!(initialize_price != 0);
    emit(SetInitializePrice(self.initialize_price, initialize_price));
    self.initialize_price = initialize_price;
}

public fun set_treasury(self: &mut XPumpConfig, _: &Admin, treasury: address) {
    emit(SetTreasury(self.treasury, treasury));
    self.treasury = treasury;
}

public fun set_reward_value(self: &mut XPumpConfig, _: &Admin, reward_value: u64) {
    emit(SetRewardValue(self.reward_value, reward_value));
    self.reward_value = reward_value;
}

public fun collect_fee<Meme>(
    config: &mut XPumpConfig,
    burn_manager: &BurnManager,
    cetus_config: &GlobalConfig,
    pool: &mut Pool<Meme, SUI>,
    _: &Admin,
    ctx: &mut TxContext,
): (Coin<Meme>, Coin<SUI>) {
    let (meme_fee, sui_fee) = burn_manager.collect_fee<Meme, SUI>(
        cetus_config,
        pool,
        config.lp_burn_proof_mut<Meme>(),
        ctx,
    );

    emit(CollectFee(object::id_address(pool), meme_fee.value(), sui_fee.value()));

    (meme_fee, sui_fee)
}

// === Private Functions ===

fun transfer_or_burn<CoinType>(coin: Coin<CoinType>, to: address) {
    if (coin.value() == 0) {
        coin.destroy_zero();
    } else {
        transfer::public_transfer(coin, to);
    }
}

fun pool_creation_cap<Meme>(config: &XPumpConfig): &PoolCreationCap {
    dof::borrow<_, PoolCreationCap>(&config.id, PoolCreationCapKey(type_name::get<Meme>()))
}

fun lp_burn_proof_mut<Meme>(config: &mut XPumpConfig): &mut CetusLPBurnProof {
    dof::borrow_mut<_, CetusLPBurnProof>(&mut config.id, LpBurnConfigKey(type_name::get<Meme>()))
}

fun save_lp_burn_proof<Meme>(config: &mut XPumpConfig, lp_burn_proof: CetusLPBurnProof) {
    dof::add(&mut config.id, LpBurnConfigKey(type_name::get<Meme>()), lp_burn_proof);
}

fun save_pool_creation_cap<Meme>(config: &mut XPumpConfig, pool_creation_cap: PoolCreationCap) {
    dof::add(&mut config.id, PoolCreationCapKey(type_name::get<Meme>()), pool_creation_cap);
}
