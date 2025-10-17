// Module: memez_presale

module memez_presale::memez_presale;

use interest_bps::bps::{Self, BPS};
use sui::{balance::Balance, coin_registry, derived_object, package, sui::SUI, table::Table};
use std::type_name::{Self, TypeName};

// === Structs ===

public struct MEMEZ_PRESALE() has drop;

public enum Methodology {
    Overflow,
    HardCap,
}

public struct Fees has copy, drop, store {
    creation: BPS,
    success: BPS,
}

public struct Account<phantom CoinType> has key {
    id: UID,
    sui_value: u64,
    coin_value: u64,
}

public struct Time has copy, drop, store {
    start: u64,
    end: u64, 
    /// Add Liquidity to the DEX
    launch: u64, 
    /// Release the coins to the users
    release: u64
}

public enum Status has copy, drop, store {
    Failed,
    Success, 
    Migrated
}

public struct Migrator<phantom CoinType> {
    witness: TypeName,
    presale: address,
    dev: address,
    coin_balance: Balance<CoinType>,
    sui_balance: Balance<SUI>,
}

public struct Presale<phantom CoinType> has key {
    id: UID,
    time: Time,
    price: u128,
    dev: address,
    maximum_purchase: Option<u64>,
    minimum_sui_to_raise: u64,
    maximum_sui_to_raise: u64,
    liquidity_sui_provision: u64,
    liquidity_coin_provision: u64,
    sui_fees: Fees,
    coin_fees: Fees,
    sui_balance: Balance<SUI>,
    coin_balance: Balance<CoinType>,
    /// ctx.sender() -> Account.address
    accounts: Table<address, address>, 
    status: Status,
}

public struct Developer<phantom CoinType> has key {
    id: UID,
}

// === Initialization ===

fun init(otw: MEMEZ_PRESALE, ctx: &mut TxContext) {}
