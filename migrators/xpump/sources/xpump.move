module xpump_migrator::xpump_migrator;

use bluefin_spot::{config::GlobalConfig, pool::{Self, Pool}, position::Position};
use ipx_coin_standard::ipx_coin_standard::IPXTreasuryStandard;
use memez_fun::memez_fun::MemezMigrator;
use std::type_name::{Self, TypeName};
use sui::{
    clock::Clock,
    coin::{Coin, CoinMetadata},
    dynamic_field as df,
    event::emit,
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

public struct PositionKey(TypeName) has copy, drop, store;

public struct PositionData has store {
    dev: address,
    position: Position,
}

// === Events ===

public struct NewPool has copy, drop {
    pool: address,
    tick_spacing: u32,
    meme: TypeName,
    meme_amount: u64,
    sui_amount: u64,
    position: address,
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

public fun migrate<Meme, CoinTypeFee>(
    config: &mut XPumpConfig,
    bluefin_config: &mut GlobalConfig,
    clock: &Clock,
    ipx_treasury: &IPXTreasuryStandard,
    sui_metadata: &CoinMetadata<SUI>,
    meme_metadata: &CoinMetadata<Meme>,
    migrator: MemezMigrator<Meme, SUI>,
    fee: Coin<CoinTypeFee>,
    ctx: &mut TxContext,
): Coin<SUI> {
    assert!(meme_metadata.get_decimals() == MEME_DECIMALS, EInvalidDecimals);
    assert!(ipx_treasury.total_supply<Meme>() == MEME_TOTAL_SUPPLY, EInvalidTotalSupply);

    let (dev, meme_balance, mut sui_balance) = migrator.destroy(Witness());

    let reward = sui_balance.split(config.reward_value).into_coin(ctx);

    let meme_balance_value = meme_balance.value();

    let (
        pool_id,
        position,
        meme_amount,
        sui_amount,
        excess_meme,
        excess_sui,
    ) = pool::create_pool_with_liquidity<Meme, SUI, CoinTypeFee>(
        clock,
        bluefin_config,
        pool_name<Meme>(meme_metadata),
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
        config.initialize_price,
        fee.into_balance(),
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
        meme_amount,
        sui_amount,
        position: object::id_address(&position),
    });

    config.save_position<Meme>(PositionData {
        dev,
        position,
    });

    transfer_or_burn(excess_meme.into_coin(ctx), DEAD_ADDRESS);
    transfer_or_burn(excess_sui.into_coin(ctx), config.treasury);

    reward
}

public fun collect_fee<Meme>(
    config: &mut XPumpConfig,
    bluefin_config: &GlobalConfig,
    pool: &mut Pool<Meme, SUI>,
    clock: &Clock,
    ctx: &mut TxContext,
): (Coin<Meme>, Coin<SUI>) {
    let position_data = position_mut<Meme>(config);

    let sender = ctx.sender();

    assert!(sender == position_data.dev);

    let (meme_amount, sui_amount, meme_balance, sui_balance) = pool::collect_fee<Meme, SUI>(
        clock,
        bluefin_config,
        pool,
        &mut position_data.position,
    );

    emit(CollectFee(sender, meme_amount, sui_amount));

    (meme_balance.into_coin(ctx), sui_balance.into_coin(ctx))
}

// === View Functions ===

public fun position_dev<Meme>(config: &XPumpConfig): address {
    get_position<Meme>(config).dev
}

public fun position<Meme>(config: &XPumpConfig): &Position {
    &get_position<Meme>(config).position
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

// === Private Functions ===

fun pool_name<Meme>(meme_metadata: &CoinMetadata<Meme>): vector<u8> {
    let mut name = b"xPump-";

    name.append(meme_metadata.get_name().into_bytes());
    name.append(b"/");
    name.append(b"SUI");

    name
}

fun transfer_or_burn<CoinType>(coin: Coin<CoinType>, to: address) {
    if (coin.value() == 0) {
        coin.destroy_zero();
    } else {
        transfer::public_transfer(coin, to);
    }
}

fun get_position<Meme>(config: &XPumpConfig): &PositionData {
    df::borrow<_, PositionData>(&config.id, PositionKey(type_name::get<Meme>()))
}

fun position_mut<Meme>(config: &mut XPumpConfig): &mut PositionData {
    df::borrow_mut<_, PositionData>(&mut config.id, PositionKey(type_name::get<Meme>()))
}

fun save_position<Meme>(config: &mut XPumpConfig, position: PositionData) {
    df::add(&mut config.id, PositionKey(type_name::get<Meme>()), position);
}
