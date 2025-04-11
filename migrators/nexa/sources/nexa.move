module nexa::nexa_migrator;

use bluefin_spot::{config::GlobalConfig, pool::{Self, Pool, create_pool_with_liquidity}};
use ipx_coin_standard::ipx_coin_standard::IPXTreasuryStandard;
use memez_fun::memez_fun::MemezMigrator;
use std::type_name::{Self, TypeName};
use sui::{clock::Clock, coin::{Coin, CoinMetadata}, event::emit, sui::SUI};

// === Constants ===

const DEAD_ADDRESS: address = @0x0;

const TICK_SPACING: u32 = 200;

// @dev Refer to https://github.com/interest-protocol/memez.gg-sdk/blob/main/src/scripts/memez/cetus-price.ts
// This means that 1 Meme coin equals to 0.000012 Sui.
const INITIALIZE_PRICE: u128 = 63901395939770060;

// source: https://suiscan.xyz/mainnet/object/0x03db251ba509a8d5d8777b6338836082335d93eecbdd09a11e190a1cff51c352/fields
const MIN_TICK: u32 = 4294523660;

// source: https://suiscan.xyz/mainnet/object/0x03db251ba509a8d5d8777b6338836082335d93eecbdd09a11e190a1cff51c352/fields
const MAX_TICK: u32 = 443636;

const MEME_DECIMALS: u8 = 9;

const MEME_TOTAL_SUPPLY: u64 = 1_000_000_000_000_000_000;

// 1%
const FEE_BASIS_POINTS: u64 = 10_000;

const ONE_SUI: u64 = 1_000_000_000;

// === Errors ===

const EInvalidTickSpacing: u64 = 0;

const EInvalidDecimals: u64 = 1;

const EInvalidTotalSupply: u64 = 2;

// === Structs ===

public struct Admin has key, store {
    id: UID,
}

public struct Witness() has drop;

public struct NexaConfig has key {
    id: UID,
    initialize_price: u128,
    treasury: address,
    migrator_reward: u64,
}

// === Events ===

public struct NewPool has copy, drop {
    pool: address,
    tick_spacing: u32,
    meme: TypeName,
    sui_balance: u64,
    meme_balance: u64,
}

public struct AddToExistingPool has copy, drop {
    pool: address,
    tick_spacing: u32,
    meme: TypeName,
    sui_balance: u64,
    meme_balance: u64,
}

public struct SetTreasury(address, address) has copy, drop;

public struct SetInitializePrice(u128, u128) has copy, drop;

public struct UpdateMigratorReward(u64, u64) has copy, drop;

// === Initializer ===

fun init(ctx: &mut TxContext) {
    let recrd = NexaConfig {
        id: object::new(ctx),
        initialize_price: INITIALIZE_PRICE,
        treasury: @treasury,
        migrator_reward: ONE_SUI,
    };

    let admin = Admin {
        id: object::new(ctx),
    };

    transfer::share_object(recrd);
    transfer::share_object(admin);
}

// === Public Mutative Functions ===

public fun migrate_to_new_pool<Meme, CoinTypeFee>(
    nexa_config: &NexaConfig,
    clock: &Clock,
    protocol_config: &mut GlobalConfig,
    pool_name: vector<u8>,
    pool_icon_url: vector<u8>,
    coin_a_symbol: vector<u8>,
    coin_a_url: vector<u8>,
    coin_b_symbol: vector<u8>,
    coin_b_url: vector<u8>,
    creation_fee: Coin<CoinTypeFee>,
    ipx_treasury: &IPXTreasuryStandard,
    meme_metadata: &CoinMetadata<Meme>,
    migrator: MemezMigrator<Meme, SUI>,
    ctx: &mut TxContext,
): Coin<SUI> {
    assert!(meme_metadata.get_decimals() == MEME_DECIMALS, EInvalidDecimals);
    assert!(ipx_treasury.total_supply<Meme>() == MEME_TOTAL_SUPPLY, EInvalidTotalSupply);

    let (meme_balance, mut sui_balance) = migrator.destroy(Witness());

    let reward = sui_balance.split(nexa_config.migrator_reward).into_coin(ctx);

    let meme_balance_value = meme_balance.value();

    let (
        pool_id,
        position,
        amount_meme_provided,
        amount_sui_provided,
        extra_meme,
        extra_sui,
    ) = create_pool_with_liquidity<Meme, SUI, CoinTypeFee>(
        clock,
        protocol_config,
        pool_name,
        pool_icon_url,
        coin_a_symbol,
        9,
        coin_a_url,
        coin_b_symbol,
        9,
        coin_b_url,
        TICK_SPACING,
        FEE_BASIS_POINTS,
        nexa_config.initialize_price,
        creation_fee.into_balance(),
        MIN_TICK,
        MAX_TICK,
        meme_balance,
        sui_balance,
        meme_balance_value,
        true,
        ctx,
    );

    emit(NewPool {
        pool: pool_id.to_address(),
        tick_spacing: TICK_SPACING,
        meme: type_name::get<Meme>(),
        meme_balance: amount_meme_provided,
        sui_balance: amount_sui_provided,
    });

    // !Important for test we send to treasury - REPLACE TO DEAD AFTER
    transfer::public_transfer(position, nexa_config.treasury);

    transfer_or_burn(extra_meme.into_coin(ctx), DEAD_ADDRESS);
    transfer_or_burn(extra_sui.into_coin(ctx), nexa_config.treasury);

    reward
}

// @dev We do not need to check decimals nor total supply here because we do not set the initial price.
public fun migrate_to_existing_pool<Meme>(
    nexa_config: &NexaConfig,
    protocol_config: &mut GlobalConfig,
    clock: &Clock,
    pool: &mut Pool<Meme, SUI>,
    migrator: MemezMigrator<Meme, SUI>,
    ctx: &mut TxContext,
): Coin<SUI> {
    assert!(pool.get_tick_spacing() == TICK_SPACING, EInvalidTickSpacing);

    let (meme_balance, mut sui_balance) = migrator.destroy(Witness());

    let reward = sui_balance.split(nexa_config.migrator_reward).into_coin(ctx);

    let mut position = pool::open_position(protocol_config, pool, MIN_TICK, MAX_TICK, ctx);

    let meme_balance_value = meme_balance.value();

    let (
        amount_meme_provided,
        amount_sui_provided,
        extra_meme,
        extra_sui,
    ) = pool::add_liquidity_with_fixed_amount(
        clock,
        protocol_config,
        pool,
        &mut position,
        meme_balance,
        sui_balance,
        meme_balance_value,
        true,
    );

    emit(AddToExistingPool {
        pool: object::id(pool).to_address(),
        tick_spacing: TICK_SPACING,
        meme: type_name::get<Meme>(),
        meme_balance: amount_meme_provided,
        sui_balance: amount_sui_provided,
    });

    // !Important for test we send to treasury - REPLACE TO DEAD AFTER
    transfer::public_transfer(position, nexa_config.treasury);
    transfer_or_burn(extra_meme.into_coin(ctx), DEAD_ADDRESS);
    transfer_or_burn(extra_sui.into_coin(ctx), nexa_config.treasury);

    reward
}

// === Admin Functions ===

public fun set_initialize_price(self: &mut NexaConfig, _: &Admin, initialize_price: u128) {
    assert!(initialize_price != 0);
    emit(SetInitializePrice(self.initialize_price, initialize_price));
    self.initialize_price = initialize_price;
}

public fun set_treasury(self: &mut NexaConfig, _: &Admin, treasury: address) {
    emit(SetTreasury(self.treasury, treasury));
    self.treasury = treasury;
}

public fun update_migrator_reward(self: &mut NexaConfig, _: &Admin, migrator_reward: u64) {
    emit(UpdateMigratorReward(self.migrator_reward, migrator_reward));
    self.migrator_reward = migrator_reward;
}

// === Private Functions ===

fun transfer_or_burn<CoinType>(coin: Coin<CoinType>, to: address) {
    if (coin.value() == 0) {
        coin.destroy_zero();
    } else {
        transfer::public_transfer(coin, to);
    }
}
