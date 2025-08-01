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

const TREASURY_FEE: u64 = 5_000;

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
    treasury_fee: BPS,
}

public struct PositionOwner has key, store {
    id: UID,
    pool: address,
    position: address,
    meme: TypeName,
}

public struct PositionKey(TypeName) has copy, drop, store;

public struct PositionData<phantom Meme> has store {
    pool: address,
    position: Position,
    position_owner: address,
    meme_balance: Balance<Meme>,
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
    assert!(meme_metadata.get_decimals() == MEME_DECIMALS, EInvalidDecimals);
    assert!(ipx_treasury.total_supply<Meme>() == MEME_TOTAL_SUPPLY, EInvalidTotalSupply);

    let (dev, meme_balance, mut sui_balance) = migrator.destroy(Witness());

    let reward = sui_balance.split(config.reward_value).into_coin(ctx);

    let sui_balance_value = sui_balance.value();

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
        sui_balance_value,
        false,
        ctx,
    );

    let pool_address = pool_id.to_address();

    emit(NewPool {
        pool: pool_address,
        tick_spacing: TICK_SPACING,
        meme: type_name::get<Meme>(),
        meme_amount,
        sui_amount,
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
        meme_balance: balance::zero(),
        sui_balance: balance::zero(),
    });

    transfer::public_transfer(position_owner, dev);

    destroy_zero_or_transfer(excess_meme.into_coin(ctx), DEAD_ADDRESS);
    destroy_zero_or_transfer(excess_sui.into_coin(ctx), config.treasury);

    reward
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
    assert!(meme_metadata.get_decimals() == MEME_DECIMALS, EInvalidDecimals);
    assert!(ipx_treasury.total_supply<Meme>() == MEME_TOTAL_SUPPLY, EInvalidTotalSupply);
    assert!(pool.get_fee_rate() == FEE_RATE);
    assert!(pool.get_tick_spacing() == TICK_SPACING);

    let (dev, meme_balance, mut sui_balance) = migrator.destroy(Witness());

    let reward = sui_balance.split(config.reward_value).into_coin(ctx);

    let sui_balance_value = sui_balance.value();

    let mut position = pool::open_position<Meme, SUI>(
        bluefin_config,
        pool,
        MIN_TICK,
        MAX_TICK,
        ctx,
    );

    let pool_address = object::id_address(pool);

    let (meme_amount, sui_amount, excess_meme, excess_sui) = pool::add_liquidity_with_fixed_amount<
        Meme,
        SUI,
    >(
        clock,
        bluefin_config,
        pool,
        &mut position,
        meme_balance,
        sui_balance,
        sui_balance_value,
        false,
    );

    emit(NewPool {
        pool: pool_address,
        tick_spacing: TICK_SPACING,
        meme: type_name::get<Meme>(),
        meme_amount,
        sui_amount,
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
        meme_balance: balance::zero(),
        sui_balance: balance::zero(),
    });

    transfer::public_transfer(position_owner, dev);

    destroy_zero_or_transfer(excess_meme.into_coin(ctx), DEAD_ADDRESS);
    destroy_zero_or_transfer(excess_sui.into_coin(ctx), config.treasury);

    reward
}

public fun collect_fee<Meme>(
    config: &mut XPumpConfig,
    bluefin_config: &GlobalConfig,
    pool: &mut Pool<Meme, SUI>,
    clock: &Clock,
    position_owner: &PositionOwner,
    ctx: &mut TxContext,
): (Coin<Meme>, Coin<SUI>) {
    let treasury_fee = config.treasury_fee;

    let position_data = position_mut<Meme>(config);

    assert!(position_owner.position == object::id_address(&position_data.position));
    assert!(position_owner.pool == object::id_address(pool));

    let (meme_amount, sui_amount, mut meme_balance, mut sui_balance) = pool::collect_fee<Meme, SUI>(
        clock,
        bluefin_config,
        pool,
        &mut position_data.position,
    );

    let meme_treasury_fee = meme_balance.split(treasury_fee.calc_up(meme_amount));
    let sui_treasury_fee = sui_balance.split(treasury_fee.calc_up(sui_amount));

    emit(CollectFee {
        pool: position_data.pool,
        position_owner: position_owner.id.to_address(),
        position: object::id_address(&position_data.position),
        owner_meme_amount: meme_balance.value(),
        owner_sui_amount: sui_balance.value(),
        treasury_meme_amount: meme_treasury_fee.value(),
        treasury_sui_amount: sui_treasury_fee.value(),
    });

    meme_balance.join(position_data.meme_balance.withdraw_all());
    sui_balance.join(position_data.sui_balance.withdraw_all());

    transfer::public_transfer(meme_treasury_fee.into_coin(ctx), config.treasury);
    transfer::public_transfer(sui_treasury_fee.into_coin(ctx), config.treasury);

    (meme_balance.into_coin(ctx), sui_balance.into_coin(ctx))
}

public fun treasury_collect_fee<Meme>(
    config: &mut XPumpConfig,
    bluefin_config: &GlobalConfig,
    pool: &mut Pool<Meme, SUI>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let treasury_fee = config.treasury_fee;

    let position_data = position_mut<Meme>(config);

    assert!(position_data.pool == object::id_address(pool));

    let (meme_amount, sui_amount, mut meme_balance, mut sui_balance) = pool::collect_fee<Meme, SUI>(
        clock,
        bluefin_config,
        pool,
        &mut position_data.position,
    );

    let meme_treasury_fee = meme_balance.split(treasury_fee.calc_up(meme_amount));
    let sui_treasury_fee = sui_balance.split(treasury_fee.calc_up(sui_amount));

    emit(CollectFee {
        pool: position_data.pool,
        position_owner: position_data.position_owner,
        position: object::id_address(&position_data.position),
        owner_meme_amount: meme_balance.value(),
        owner_sui_amount: sui_balance.value(),
        treasury_meme_amount: meme_treasury_fee.value(),
        treasury_sui_amount: sui_treasury_fee.value(),
    });

    position_data.meme_balance.join(meme_balance);
    position_data.sui_balance.join(sui_balance);

    transfer::public_transfer(meme_treasury_fee.into_coin(ctx), config.treasury);
    transfer::public_transfer(sui_treasury_fee.into_coin(ctx), config.treasury);
}

// === View Functions ===

public fun position_pool<Meme>(config: &XPumpConfig): address {
    get_position<Meme>(config).pool
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

public fun set_treasury_fee(self: &mut XPumpConfig, _: &Admin, treasury_fee: u64) {
    emit(SetTreasuryFee(self.treasury_fee.value(), treasury_fee));
    self.treasury_fee = bps::new(treasury_fee);
}

// === Private Functions ===

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

fun position_mut<Meme>(config: &mut XPumpConfig): &mut PositionData<Meme> {
    df::borrow_mut<_, PositionData<Meme>>(&mut config.id, PositionKey(type_name::get<Meme>()))
}

fun save_position<Meme>(config: &mut XPumpConfig, position: PositionData<Meme>) {
    df::add(&mut config.id, PositionKey(type_name::get<Meme>()), position);
}
