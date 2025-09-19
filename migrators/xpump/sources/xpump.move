#[allow(lint(self_transfer), unused_variable, unused_field)]
module xpump_migrator::xpump_migrator;

use bluefin_spot::{config::GlobalConfig, pool::{Self, Pool}, position::Position};
use interest_bps::bps::{Self, BPS};
use ipx_coin_standard::ipx_coin_standard::IPXTreasuryStandard;
use memez_fun::memez_fun::MemezMigrator;
use std::type_name::{Self, TypeName};
use sui::{
    balance::{Self, Balance},
    clock::Clock,
    coin::{Coin, CoinMetadata},
    dynamic_field as df,
    event::emit,
    sui::SUI,
    url
};
use xpump_migrator::math;

// === Constants ===

const DEAD_ADDRESS: address = @0x0;

// https://cetus-1.gitbook.io/cetus-developer-docs/developer/via-contract/features-available/create-pool
const TICK_SPACING: u32 = 200;

const FEE_RATE: u64 = 10000;

// @dev Refer to https://github.com/interest-protocol/memez.gg-sdk/blob/main/src/scripts/memez/cetus-price.ts
// This means that 1 Meme coin equals to 0.000012 Sui.
const INITIALIZE_PRICE: u128 = 63901395939770060;

const MEME_DECIMALS: u8 = 9;

const ONE_SUI: u64 = 1_000_000_000;

const TREASURY_FEE: u64 = 5_000;

const PACKAGE_VERSION: u64 = 4;

// === Errors ===

const EInvalidDecimals: u64 = 0;

const EInvalidPackageVersion: u64 = 2;

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
    treasury_fee: BPS,
    package_version: u64,
}

public struct PositionOwner has key, store {
    id: UID,
    pool: address,
    position: address,
    meme: TypeName,
}

public struct Ticks has store {
    min: u32,
    max: u32,
}

public struct LiquidityMarginKey() has copy, drop, store;

public struct TicksKey() has copy, drop, store;

public struct PositionKey(TypeName) has copy, drop, store;

public struct PositionKeyV2(TypeName) has copy, drop, store;

public struct PositionData<phantom Meme> has store {
    pool: address,
    position: Position,
    position_owner: address,
    sui_balance: Balance<SUI>,
}

// === Events ===

public struct NewPool has copy, drop {
    pool: address,
    tick_spacing: u32,
    meme: TypeName,
    meme_amount: u64,
    sui_amount: u64,
    position: address,
    dev: address,
}

public struct SetTreasury(address, address) has copy, drop;

public struct SetInitializePrice(u128, u128) has copy, drop;

public struct SetRewardValue(u64, u64) has copy, drop;

public struct SetTreasuryFee(u64, u64) has copy, drop;

public struct UpdatePositionOwner has copy, drop {
    old_position_owner: address,
    new_position_owner: address,
    meme: TypeName,
}

public struct CollectFee has copy, drop {
    pool: address,
    position_owner: address,
    position: address,
    owner_meme_amount: u64,
    owner_sui_amount: u64,
    treasury_meme_amount: u64,
    treasury_sui_amount: u64,
}

// === Initializer ===

fun init(ctx: &mut TxContext) {
    let xpump_config = XPumpConfig {
        id: object::new(ctx),
        initialize_price: INITIALIZE_PRICE,
        treasury: @treasury,
        reward_value: ONE_SUI,
        treasury_fee: bps::new(TREASURY_FEE),
        package_version: PACKAGE_VERSION,
    };

    let admin = Admin {
        id: object::new(ctx),
    };

    transfer::share_object(xpump_config);
    transfer::public_transfer(admin, ctx.sender());
}

// === Public Mutative Functions ===

public fun migrate_to_new_pool<Meme, CoinTypeFee>(
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
    abort
}

public fun migrate_to_new_pool_v2<Meme, Quote, CoinTypeFee>(
    config: &mut XPumpConfig,
    bluefin_config: &mut GlobalConfig,
    clock: &Clock,
    ipx_treasury: &IPXTreasuryStandard,
    meme_metadata: &CoinMetadata<Meme>,
    quote_metadata: &CoinMetadata<Quote>,
    migrator: MemezMigrator<Meme, Quote>,
    fee: Coin<CoinTypeFee>,
    ctx: &mut TxContext,
): Coin<Quote> {
    abort
}

public fun migrate_to_new_pool_v3<Meme, Quote, CoinTypeFee>(
    config: &mut XPumpConfig,
    bluefin_config: &mut GlobalConfig,
    clock: &Clock,
    ipx_treasury: &IPXTreasuryStandard,
    meme_metadata: &CoinMetadata<Meme>,
    quote_metadata: &CoinMetadata<Quote>,
    migrator: MemezMigrator<Meme, Quote>,
    fee: Coin<CoinTypeFee>,
    ctx: &mut TxContext,
): Coin<Quote> {
    config.assert_package_version();

    assert!(meme_metadata.get_decimals() == MEME_DECIMALS, EInvalidDecimals);

    let (dev, meme_balance, mut quote_balance) = migrator.destroy(Witness());

    let reward = quote_balance.split(config.reward_value).into_coin(ctx);

    let liquidity_margin = get_liquidity_margin(config);

    let safe_meme_balance_value =
        meme_balance.value() - liquidity_margin.calc_up(meme_balance.value());

    let price =
        math::sqrt_down((
            (quote_balance.value() as u256) * 2u256.pow(128) / (safe_meme_balance_value as u256),
        )) as u128;

    let mut bluefin_pool = pool::create_pool_and_get_object<Meme, Quote, CoinTypeFee>(
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
        quote_metadata.get_symbol().into_bytes(),
        quote_metadata.get_decimals(),
        quote_metadata
            .get_icon_url()
            .destroy_with_default(url::new_unsafe_from_bytes(x""))
            .inner_url()
            .into_bytes(),
        TICK_SPACING,
        FEE_RATE,
        price,
        fee.into_balance(),
        ctx,
    );

    let ticks = get_ticks(config);

    let mut position = pool::open_position<Meme, Quote>(
        bluefin_config,
        &mut bluefin_pool,
        ticks.min,
        ticks.max,
        ctx,
    );

    let quote_balance_value = quote_balance.value();

    let (meme_amount, sui_amount, excess_meme, excess_sui) = pool::add_liquidity_with_fixed_amount(
        clock,
        bluefin_config,
        &mut bluefin_pool,
        &mut position,
        meme_balance,
        quote_balance,
        quote_balance_value,
        false,
    );

    config.share_pool_and_save_position(
        bluefin_pool,
        position,
        meme_amount,
        sui_amount,
        excess_meme,
        excess_sui,
        dev,
        ctx,
    );

    reward
}

public fun migrate_to_new_pool_with_liquidity<Meme, CoinTypeFee>(
    config: &mut XPumpConfig,
    bluefin_config: &mut GlobalConfig,
    clock: &Clock,
    ipx_treasury: &IPXTreasuryStandard,
    sui_metadata: &CoinMetadata<SUI>,
    meme_metadata: &CoinMetadata<Meme>,
    migrator: MemezMigrator<Meme, SUI>,
    fee: Coin<CoinTypeFee>,
    liquidity: u128,
    ctx: &mut TxContext,
): Coin<SUI> {
    abort
}

public fun add_liquidity_to_existing_pool<Meme>(
    config: &mut XPumpConfig,
    bluefin_config: &mut GlobalConfig,
    pool: &mut Pool<Meme, SUI>,
    clock: &Clock,
    ipx_treasury: &IPXTreasuryStandard,
    meme_metadata: &CoinMetadata<Meme>,
    sui_coin: Coin<SUI>,
    meme_coin: Coin<Meme>,
    ctx: &mut TxContext,
) {
    abort
}

public fun migrate_to_existing_pool<Meme>(
    config: &mut XPumpConfig,
    bluefin_config: &mut GlobalConfig,
    pool: &mut Pool<Meme, SUI>,
    clock: &Clock,
    ipx_treasury: &IPXTreasuryStandard,
    meme_metadata: &CoinMetadata<Meme>,
    migrator: MemezMigrator<Meme, SUI>,
    ctx: &mut TxContext,
): Coin<SUI> {
    abort
}

public fun collect_fee<Meme>(
    config: &mut XPumpConfig,
    bluefin_config: &GlobalConfig,
    pool: &mut Pool<Meme, SUI>,
    clock: &Clock,
    position_owner: &PositionOwner,
    ctx: &mut TxContext,
): Coin<SUI> {
    config.assert_package_version();

    let treasury_fee = config.treasury_fee;

    let treasury = config.treasury;

    let position_data = config.position_mut<Meme>();

    assert!(position_owner.position == object::id_address(&position_data.position));
    assert!(position_owner.pool == object::id_address(pool));

    collect_fee_internal(
        position_data,
        bluefin_config,
        pool,
        clock,
        position_owner,
        treasury_fee,
        treasury,
        ctx,
    )
}

public fun collect_all_fees<Meme>(
    config: &mut XPumpConfig,
    bluefin_config: &GlobalConfig,
    pool: &mut Pool<Meme, SUI>,
    clock: &Clock,
    position_owner: &PositionOwner,
    ctx: &mut TxContext,
): Coin<SUI> {
    let mut fee = collect_fee(config, bluefin_config, pool, clock, position_owner, ctx);

    if (config.has_position_v2<Meme>()) {
        fee.join(collect_fee_v2_internal(config, bluefin_config, pool, clock, position_owner, ctx));
    };

    fee
}

public fun destroy_position_owner<Meme>(config: &mut XPumpConfig, position_owner: PositionOwner) {
    config.assert_package_version();

    let position_data = position_mut<Meme>(config);

    let PositionOwner {
        id,
        pool,
        position,
        meme: _,
    } = position_owner;

    assert!(position == object::id_address(&position_data.position));
    assert!(pool == position_data.pool);

    if (position_data.position_owner == id.to_address()) {
        position_data.position_owner = DEAD_ADDRESS;
    };

    id.delete();
}

public fun treasury_collect_fee<Meme>(
    config: &mut XPumpConfig,
    bluefin_config: &GlobalConfig,
    pool: &mut Pool<Meme, SUI>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    config.assert_package_version();

    let treasury_fee = config.treasury_fee;

    let position_data = position_mut<Meme>(config);

    assert!(position_data.pool == object::id_address(pool));

    let (meme_amount, sui_amount, meme_balance, mut sui_balance) = pool::collect_fee<Meme, SUI>(
        clock,
        bluefin_config,
        pool,
        &mut position_data.position,
    );

    let sui_balance_value = sui_balance.value();

    let sui_treasury_fee = sui_balance.split(treasury_fee
        .calc_up(sui_amount)
        .min(sui_balance_value));

    emit(CollectFee {
        pool: position_data.pool,
        position_owner: position_data.position_owner,
        position: object::id_address(&position_data.position),
        owner_meme_amount: 0,
        owner_sui_amount: 0,
        treasury_meme_amount: meme_amount,
        treasury_sui_amount: sui_treasury_fee.value(),
    });

    position_data.sui_balance.join(sui_balance);

    transfer::public_transfer(meme_balance.into_coin(ctx), config.treasury);
    transfer::public_transfer(sui_treasury_fee.into_coin(ctx), config.treasury);
}

// === View Functions ===

public fun position_pool<Meme>(config: &XPumpConfig): address {
    get_position<Meme>(config).pool
}

public fun position<Meme>(config: &XPumpConfig): &Position {
    &get_position<Meme>(config).position
}

public fun position_data<Meme>(config: &XPumpConfig): &PositionData<Meme> {
    get_position<Meme>(config)
}

public fun position_data_owner<Meme>(config: &XPumpConfig): address {
    get_position<Meme>(config).position_owner
}

// === Admin Functions ===

public fun treasury_collect_position_v2_fee<Meme>(
    config: &mut XPumpConfig,
    bluefin_config: &GlobalConfig,
    pool: &mut Pool<Meme, SUI>,
    clock: &Clock,
    _: &Admin,
    ctx: &mut TxContext,
): (Coin<Meme>, Coin<SUI>) {
    let position_v2_data = config.position_mut_v2<Meme>();

    let (meme_amount, sui_amount, meme_balance, sui_balance) = pool::collect_fee<Meme, SUI>(
        clock,
        bluefin_config,
        pool,
        &mut position_v2_data.position,
    );

    emit(CollectFee {
        pool: position_v2_data.pool,
        position_owner: position_v2_data.position_owner,
        position: object::id_address(&position_v2_data.position),
        owner_meme_amount: 0,
        owner_sui_amount: 0,
        treasury_meme_amount: meme_amount,
        treasury_sui_amount: sui_amount,
    });

    (meme_balance.into_coin(ctx), sui_balance.into_coin(ctx))
}

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

public fun set_treasury_fee(self: &mut XPumpConfig, _: &Admin, treasury_fee: u64) {
    emit(SetTreasuryFee(self.treasury_fee.value(), treasury_fee));
    self.treasury_fee = bps::new(treasury_fee);
}

public fun set_package_version(self: &mut XPumpConfig, _: &Admin, package_version: u64) {
    self.package_version = package_version;
}

public fun set_liquidity_margin(self: &mut XPumpConfig, _: &Admin, value: u64) {
    if (!df::exists_(&self.id, LiquidityMarginKey())) {
        df::add(&mut self.id, LiquidityMarginKey(), bps::new(0));
    };

    let liquidity_margin = df::borrow_mut<_, BPS>(&mut self.id, LiquidityMarginKey());

    *liquidity_margin = bps::new(value);
}

public fun set_ticks(self: &mut XPumpConfig, _: &Admin, min: u32, max: u32) {
    if (!df::exists_(&self.id, TicksKey())) {
        df::add(&mut self.id, TicksKey(), Ticks { min, max });
    };

    let ticks = df::borrow_mut<_, Ticks>(&mut self.id, TicksKey());

    ticks.min = min;
    ticks.max = max;
}

public fun set_tick_spacing(self: &mut XPumpConfig, _: &Admin, min: u32, max: u32) {
    abort
}

public fun new_position_owner<Meme>(
    self: &mut XPumpConfig,
    _: &Admin,
    ctx: &mut TxContext,
): PositionOwner {
    let position_data = position_mut<Meme>(self);

    let position_owner = PositionOwner {
        id: object::new(ctx),
        pool: position_data.pool,
        position: object::id_address(&position_data.position),
        meme: type_name::get<Meme>(),
    };

    position_data.position_owner = position_owner.id.to_address();

    position_owner
}

public fun update_position_owner<Meme>(
    self: &mut XPumpConfig,
    _: &Admin,
    new_position_owner: address,
) {
    let position_data = position_mut<Meme>(self);
    emit(UpdatePositionOwner {
        old_position_owner: position_data.position_owner,
        new_position_owner,
        meme: type_name::get<Meme>(),
    });
    position_data.position_owner = new_position_owner;
}

// === Private Functions ===

fun share_pool_and_save_position<Meme, Quote>(
    config: &mut XPumpConfig,
    bluefin_pool: Pool<Meme, Quote>,
    position: Position,
    meme_amount: u64,
    quote_amount: u64,
    excess_meme: Balance<Meme>,
    excess_quote: Balance<Quote>,
    dev: address,
    ctx: &mut TxContext,
) {
    let pool_address = object::id_address(&bluefin_pool);

    pool::share_pool_object(bluefin_pool);

    emit(NewPool {
        pool: pool_address,
        tick_spacing: TICK_SPACING,
        meme: type_name::get<Meme>(),
        meme_amount,
        sui_amount: quote_amount,
        position: object::id_address(&position),
        dev,
    });

    let position_owner = PositionOwner {
        id: object::new(ctx),
        pool: pool_address,
        position: object::id_address(&position),
        meme: type_name::get<Meme>(),
    };

    config.save_position<Meme>(PositionData {
        pool: pool_address,
        position,
        position_owner: position_owner.id.to_address(),
        sui_balance: balance::zero(),
    });

    transfer::public_transfer(position_owner, dev);

    destroy_zero_or_transfer(excess_meme.into_coin(ctx), config.treasury);
    destroy_zero_or_transfer(excess_quote.into_coin(ctx), config.treasury);
}

fun collect_fee_v2_internal<Meme>(
    config: &mut XPumpConfig,
    bluefin_config: &GlobalConfig,
    pool: &mut Pool<Meme, SUI>,
    clock: &Clock,
    position_owner: &PositionOwner,
    ctx: &mut TxContext,
): Coin<SUI> {
    let treasury_fee = config.treasury_fee;

    let treasury = config.treasury;

    let position_data = config.position_mut_v2<Meme>();

    collect_fee_internal(
        position_data,
        bluefin_config,
        pool,
        clock,
        position_owner,
        treasury_fee,
        treasury,
        ctx,
    )
}

fun collect_fee_internal<Meme>(
    position_data: &mut PositionData<Meme>,
    bluefin_config: &GlobalConfig,
    pool: &mut Pool<Meme, SUI>,
    clock: &Clock,
    position_owner: &PositionOwner,
    treasury_fee: BPS,
    treasury: address,
    ctx: &mut TxContext,
): Coin<SUI> {
    let (meme_amount, sui_amount, meme_balance, mut sui_balance) = pool::collect_fee<Meme, SUI>(
        clock,
        bluefin_config,
        pool,
        &mut position_data.position,
    );

    let sui_treasury_fee = sui_balance.split(treasury_fee.calc_up(sui_amount));

    emit(CollectFee {
        pool: position_data.pool,
        position_owner: position_owner.id.to_address(),
        position: object::id_address(&position_data.position),
        owner_meme_amount: 0,
        owner_sui_amount: sui_balance.value() + position_data.sui_balance.value(),
        treasury_meme_amount: meme_amount,
        treasury_sui_amount: sui_treasury_fee.value(),
    });

    sui_balance.join(position_data.sui_balance.withdraw_all());

    transfer::public_transfer(meme_balance.into_coin(ctx), treasury);
    transfer::public_transfer(sui_treasury_fee.into_coin(ctx), treasury);

    sui_balance.into_coin(ctx)
}

fun pool_name<Meme>(meme_metadata: &CoinMetadata<Meme>): vector<u8> {
    let mut name = b"xPump-";

    name.append(meme_metadata.get_name().into_bytes());
    name.append(b"/");
    name.append(b"SUI");

    name
}

fun destroy_zero_or_transfer<CoinType>(coin: Coin<CoinType>, to: address) {
    if (coin.value() == 0) {
        coin.destroy_zero();
    } else {
        transfer::public_transfer(coin, to);
    }
}

fun get_position<Meme>(config: &XPumpConfig): &PositionData<Meme> {
    df::borrow<_, PositionData<Meme>>(&config.id, PositionKey(type_name::get<Meme>()))
}

fun has_position_v2<Meme>(config: &XPumpConfig): bool {
    df::exists_(&config.id, PositionKeyV2(type_name::get<Meme>()))
}

fun position_mut<Meme>(config: &mut XPumpConfig): &mut PositionData<Meme> {
    df::borrow_mut<_, PositionData<Meme>>(&mut config.id, PositionKey(type_name::get<Meme>()))
}

fun position_mut_v2<Meme>(config: &mut XPumpConfig): &mut PositionData<Meme> {
    df::borrow_mut<_, PositionData<Meme>>(&mut config.id, PositionKeyV2(type_name::get<Meme>()))
}

fun save_position<Meme>(config: &mut XPumpConfig, position: PositionData<Meme>) {
    df::add(&mut config.id, PositionKey(type_name::get<Meme>()), position);
}

fun assert_package_version(config: &XPumpConfig) {
    assert!(config.package_version == PACKAGE_VERSION, EInvalidPackageVersion);
}

fun get_ticks(config: &XPumpConfig): &Ticks {
    df::borrow<_, Ticks>(&config.id, TicksKey())
}

fun get_liquidity_margin(config: &XPumpConfig): BPS {
    *df::borrow<_, BPS>(&config.id, LiquidityMarginKey())
}
