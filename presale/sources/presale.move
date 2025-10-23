// Module: memez_presale

module memez_presale::memez_presale;

use interest_access_control::access_control::{Self, AdminWitness};
use interest_bps::bps::{Self, BPS};
use std::{string::String, type_name::{Self, TypeName}};
use sui::{
    balance::{Self, Balance},
    clock::Clock,
    coin::Coin,
    coin_registry::{CoinRegistry, MetadataCap},
    package,
    sui::SUI,
    table::{Self, Table}
};
use memez_presale::memez_allocation::{Self, Allocation};

// === Structs ===

public struct MEMEZ_PRESALE() has drop;

public enum Methodology has copy, drop, store {
    HardCap,
    Overflow,
}

public struct SuccessFees has copy, drop, store {
    coin: BPS,
    sui: BPS,
}

public struct Phase has copy, drop, store {
    start: u64,
    end: u64,
    price: u128,
}

public struct Time has copy, drop, store {
    phases: vector<Phase>,
    /// Add Liquidity to the DEX
    launch: u64,
    /// Release the coins to the users
    release: u64,
}

public enum Status has copy, drop, store {
    Created,
    Failed,
    Success,
    Migrated,
}

public enum SupplyType has copy, drop, store {
    Fixed,
    Burnable,
}

public struct Balances<phantom CoinType> has store {
    sui: Balance<SUI>,
    coin: Balance<CoinType>,
}

public struct PresaleConstructor has copy, drop {
    time: Option<Time>,
    price: Option<u128>,
    methodology: Option<Methodology>,
    maximum_purchase: Option<u64>,
    minimum_sui_to_raise: Option<u64>,
    maximum_sui_to_raise: Option<u64>,
    liquidity_sui_provision: Option<u64>,
    liquidity_coin_provision: Option<u64>,
    creation_sui_fee: u64,
    success_fees: SuccessFees,
    coin_decimals: Option<u8>,
    coin_total_supply: Option<u64>,
    coin_name: Option<String>,
    coin_symbol: Option<String>,
    coin_description: Option<String>,
    coin_icon_url: Option<String>,
    coin_supply_type: Option<SupplyType>,
    whitelist_merkle_root: vector<u8>,
}

// === Hot Potato ===

public struct Migrator<phantom CoinType> {
    witness: TypeName,
    presale: address,
    dev: address,
    coin_balance: Balance<CoinType>,
    sui_balance: Balance<SUI>,
}

// === Owned Objects ===

public struct Account<phantom CoinType> has key {
    id: UID,
    sui_value: u64,
    coin_value: u64,
}

public struct Developer<phantom CoinType> has key {
    id: UID,
}

// === Shared Objects ===

public struct MemezPresale<phantom CoinType> has key {
    id: UID,
    time: Time,
    price: u128,
    dev: address,
    methodology: Methodology,
    maximum_purchase: u64,
    minimum_sui_to_raise: u64,
    maximum_sui_to_raise: u64,
    liquidity_sui_provision: u64,
    liquidity_coin_provision: u64,
    success_fees: SuccessFees,
    balances: Balances<CoinType>,
    fee_balances: Balances<CoinType>,
    /// ctx.sender() -> Account.address
    accounts: Table<address, address>,
    status: Status,
    metadata_cap: MetadataCap<CoinType>,
    allocation: Allocation<CoinType>,
    whitelist_merkle_root: vector<u8>,
}

public struct Config has key {
    id: UID,
    creation_sui_fee: u64,
    success_fees: SuccessFees,
}

// === Initialization ===

fun init(otw: MEMEZ_PRESALE, ctx: &mut TxContext) {
    transfer::share_object(Config {
        id: object::new(ctx),
        creation_sui_fee: 0,
        success_fees: SuccessFees {
            coin: bps::new(0),
            sui: bps::new(0),
        },
    });
    transfer::public_share_object(access_control::default(&otw, ctx));
    package::claim_and_keep(otw, ctx);
}

// === Constructor Functions ===

public fun initialize(config: &Config): PresaleConstructor {
    PresaleConstructor {
        time: option::none(),
        price: option::none(),
        methodology: option::none(),
        maximum_purchase: option::none(),
        minimum_sui_to_raise: option::none(),
        maximum_sui_to_raise: option::none(),
        liquidity_sui_provision: option::none(),
        liquidity_coin_provision: option::none(),
        creation_sui_fee: config.creation_sui_fee,
        success_fees: config.success_fees,
        coin_decimals: option::none(),
        coin_total_supply: option::none(),
        coin_name: option::none(),
        coin_symbol: option::none(),
        coin_description: option::none(),
        coin_icon_url: option::none(),
        coin_supply_type: option::none(),
        whitelist_merkle_root: vector[],
    }
}

public fun set_time(
    constructor: &mut PresaleConstructor,
    clock: &Clock,
    launch: u64,
    release: u64,
) {
    assert!(launch >= clock.timestamp_ms(), memez_presale::memez_errors::invalid_launch!());
    assert!(release >= launch, memez_presale::memez_errors::invalid_release!());

    constructor.time = option::some(Time { launch, release, phases: vector[] });
}

public fun add_phase(constructor: &mut PresaleConstructor, clock: &Clock, start: u64, end: u64, price: u128) {
    assert!(start >= clock.timestamp_ms(), memez_presale::memez_errors::invalid_start!());
    assert!(end > start, memez_presale::memez_errors::invalid_end!());
    constructor.time.borrow_mut().phases.push_back(Phase { start, end, price });
}

public fun set_price(constructor: &mut PresaleConstructor, price: u128) {
    assert!(price > 0, memez_presale::memez_errors::zero_price!());

    constructor.price = option::some(price);
}

public fun set_whitelist_merkle_root(constructor: &mut PresaleConstructor, whitelist_merkle_root: vector<u8>) {
    constructor.whitelist_merkle_root = whitelist_merkle_root;
}

public fun set_methodology_overflow(constructor: &mut PresaleConstructor) {
    assert!(constructor.methodology.is_none());
    constructor.methodology = option::some(Methodology::Overflow);
}

public fun set_methodology_hard_cap(constructor: &mut PresaleConstructor) {
    assert!(constructor.methodology.is_none());
    constructor.methodology = option::some(Methodology::HardCap);
}

public fun set_coin_supply_type_burnable(constructor: &mut PresaleConstructor) {
    assert!(constructor.coin_supply_type.is_none());
    constructor.coin_supply_type = option::some(SupplyType::Burnable);
}

public fun set_coin_supply_type_fixed(constructor: &mut PresaleConstructor) {
    assert!(constructor.coin_supply_type.is_none());
    constructor.coin_supply_type = option::some(SupplyType::Fixed);
}

public fun set_maximum_purchase(constructor: &mut PresaleConstructor, maximum_purchase: u64) {
    assert!(maximum_purchase > 0, memez_presale::memez_errors::zero_maximum_purchase!());
    constructor.maximum_purchase = option::some(maximum_purchase);
}

public fun set_raise_amounts(
    constructor: &mut PresaleConstructor,
    minimum_sui_to_raise: u64,
    maximum_sui_to_raise: u64,
) {
    assert!(minimum_sui_to_raise > 0, memez_presale::memez_errors::zero_minimum_sui_to_raise!());
    assert!(
        maximum_sui_to_raise > minimum_sui_to_raise,
        memez_presale::memez_errors::invalid_maximum_sui_to_raise!(),
    );
    constructor.minimum_sui_to_raise = option::some(minimum_sui_to_raise);
    constructor.maximum_sui_to_raise = option::some(maximum_sui_to_raise);
}

public fun set_coin_metadata(
    constructor: &mut PresaleConstructor,
    coin_total_supply: u64,
    coin_name: String,
    coin_symbol: String,
    coin_description: String,
    coin_icon_url: String,
    coin_decimals: u8,
) {
    assert!(coin_decimals > 0, memez_presale::memez_errors::zero_coin_decimals!());
    assert!(coin_total_supply > 0, memez_presale::memez_errors::zero_coin_total_supply!());

    constructor.coin_decimals = option::some(coin_decimals);
    constructor.coin_total_supply = option::some(coin_total_supply);
    constructor.coin_name = option::some(coin_name);
    constructor.coin_symbol = option::some(coin_symbol);
    constructor.coin_description = option::some(coin_description);
    constructor.coin_icon_url = option::some(coin_icon_url);
}

public fun finalize<CoinType: copy + drop + store>(
    constructor: PresaleConstructor,
    coin_registry: &mut CoinRegistry,
    _: &CoinType,
    sui_fee: Coin<SUI>,
    allocation_bps_value: u64,
    ctx: &mut TxContext,
): (MemezPresale<MemezPresale<CoinType>>, Developer<MemezPresale<CoinType>>) {
    assert!(sui_fee.value() >= constructor.creation_sui_fee, memez_presale::memez_errors::insufficient_sui_fee!());

    let (mut currency_initializer, mut treasury_cap) = coin_registry.new_currency<
        MemezPresale<CoinType>,
    >(
        constructor.coin_decimals.destroy_some(),
        constructor.coin_symbol.destroy_some(),
        constructor.coin_name.destroy_some(),
        constructor.coin_description.destroy_some(),
        constructor.coin_icon_url.destroy_some(),
        ctx,
    );

    let mut coin_balance = treasury_cap.mint_balance(constructor.coin_total_supply.destroy_some());
    
    let coin_allocation = if (allocation_bps_value > 0) {
        let coin_balance_value = coin_balance.value();
        coin_balance.split(bps::new(allocation_bps_value).calc(coin_balance_value))
    } else {
        balance::zero()
    };

    match (constructor.coin_supply_type.destroy_some()) {
        SupplyType::Burnable => {
            currency_initializer.make_supply_burn_only(treasury_cap);
        },
        SupplyType::Fixed => {
            currency_initializer.make_supply_fixed(treasury_cap);
        },
    };

    let metadata_cap = currency_initializer.finalize(ctx);

    let developer = Developer {
        id: object::new(ctx),
    };

    let presale = MemezPresale {
        id: object::new(ctx),
        time: constructor.time.destroy_some(),
        price: constructor.price.destroy_some(),
        dev: ctx.sender(),
        methodology: constructor.methodology.destroy_some(),
        maximum_purchase: constructor.maximum_purchase.destroy_with_default(std::u64::max_value!()),
        minimum_sui_to_raise: constructor.minimum_sui_to_raise.destroy_some(),
        maximum_sui_to_raise: constructor.maximum_sui_to_raise.destroy_some(),
        liquidity_sui_provision: constructor.liquidity_sui_provision.destroy_some(),
        liquidity_coin_provision: constructor.liquidity_coin_provision.destroy_some(),
        success_fees: constructor.success_fees,
        balances: Balances {
            sui: balance::zero(),
            coin: coin_balance,
        },
        fee_balances: Balances {
            sui: sui_fee.into_balance(),
            coin: balance::zero(),
        },
        accounts: table::new(ctx),
        status: Status::Created,
        metadata_cap,
        allocation: memez_allocation::new_allocation(coin_allocation),
        whitelist_merkle_root: constructor.whitelist_merkle_root,
    };

    (presale, developer)
}

public fun share_presale<CoinType>(presale: MemezPresale<CoinType>) {
    transfer::share_object(presale);
}

public fun keep_developer<CoinType>(developer: Developer<MemezPresale<CoinType>>, ctx: &TxContext) {
    transfer::transfer(developer, ctx.sender());
}

// === Admin Functions ===

public fun set_creation_sui_fee(
    config: &mut Config,
    _: &AdminWitness<MEMEZ_PRESALE>,
    creation_sui_fee: u64,
    _: &mut TxContext,
) {
    config.creation_sui_fee = creation_sui_fee;
}

public fun set_success_fees(
    config: &mut Config,
    _: &AdminWitness<MEMEZ_PRESALE>,
    coin: u64,
    sui: u64,
    _: &mut TxContext,
) {
    config.success_fees.coin = bps::new(coin);
    config.success_fees.sui = bps::new(sui);
}
