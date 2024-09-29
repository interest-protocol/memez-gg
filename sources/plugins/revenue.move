module memez_gg::revenue;
// === Imports ===

use std::type_name;

use sui::{
    sui::SUI,
    coin::Coin,
    dynamic_field as df,
};

use memez_gg::{
    fees,
    black_ice,
};

// === Errors ===

#[error]
const InvalidFeeLength: vector<u8> = b"The protocol supports 2 fees";

#[error]
const InvalidSwapFee: vector<u8> = b"The maximum swap fee is 50%";

#[error]
const InvalidLiquidityFee: vector<u8> = b"The maximum liquidity fee is 10%";

#[error]
const InvalidFreezeFee: vector<u8> = b"The maximum freeze fee is 10%";

#[error]
const InvalidAdminFee: vector<u8> = b"The maximum admin fee is 20%";

// Structs 

public struct RevenueKey() has copy, store, drop;

public struct Revenue has store {
    swap_fee: u64, 
    liquidity_management_fee: u64, 
    admin_fee: u64,
    freeze_fee: u64,
    beneficiary: address,
}

// === Public Package Functions ===

public(package) fun supports(id: &UID): bool {
    df::exists_(id, RevenueKey())
}

public(package) fun swap_fee(id: &UID): u64 {
    df::borrow<RevenueKey, Revenue>(id, RevenueKey()).swap_fee
}

public(package) fun liquidity_management_fee(id: &UID): u64 {
    df::borrow<RevenueKey, Revenue>(id, RevenueKey()).liquidity_management_fee
}

public(package) fun admin_fee(id: &UID): u64 {
    df::borrow<RevenueKey, Revenue>(id, RevenueKey()).admin_fee
} 

public(package) fun beneficiary(id: &UID): address {
    df::borrow<RevenueKey, Revenue>(id, RevenueKey()).beneficiary
}

public(package) fun new(id: &mut UID, fees: vector<u64>, beneficiary: address) {
    assert!(fees.length() == 2, InvalidFeeLength);
    assert!(fees::max_swap_fee() >= fees[0], InvalidSwapFee);
    assert!(fees::max_liquidity_management_fee() >= fees[1], InvalidLiquidityFee);
    assert!(fees::max_freeze_fee() >= fees[2], InvalidFreezeFee);

    let revenue = Revenue {
        swap_fee: fees[0],
        liquidity_management_fee: fees[1],
        freeze_fee: fees[2],
        admin_fee: fees::default_admin_fee(),
        beneficiary,
    };

    df::add(
        id, 
        RevenueKey(),
        revenue
    );   
}

public(package) fun take_swap_fee<CoinType>(id: &UID, coin: &mut Coin<CoinType>, ctx: &mut TxContext) {
    let revenue = revenue(id);

    send_fee(coin, revenue.swap_fee, revenue.admin_fee, revenue.beneficiary, ctx);
}

public(package) fun take_liquidity_management_fee<CoinType>(id: &UID, coin: &mut Coin<CoinType>, ctx: &mut TxContext) {
    let revenue = revenue(id);

    send_fee(coin, revenue.liquidity_management_fee, revenue.admin_fee, revenue.beneficiary, ctx);
}

public(package) fun take_freeze_fee<CoinType>(id: &UID, coin: &mut Coin<CoinType>, ctx: &mut TxContext) {
    let revenue = revenue(id);

    if (type_name::get<SUI>() == type_name::get<CoinType>() || revenue.freeze_fee == 0) return;

    let fee_amount = fees::calculate(coin.value(), revenue.freeze_fee);

    black_ice::freeze_it(coin.split(fee_amount, ctx), ctx);
}

public(package) fun set_admin_fee(id: &mut UID, admin_fee: u64) {
    assert!(fees::max_admin_fee() >= admin_fee, InvalidAdminFee);

    let revenue = revenue_mut(id);

    revenue.admin_fee = admin_fee;
}

// === Private Functions ===

fun send_fee<CoinType>(
    coin: &mut Coin<CoinType>,
    fee: u64,
    admin_fee: u64,
    beneficiary: address,
    ctx: &mut TxContext,
) {

    if (fee == 0) return;

    let fee_amount = fees::calculate(coin.value(), fee);
    let admin_fee_amount = fees::calculate(fee_amount, admin_fee);

    transfer::public_transfer(coin.split(fee_amount, ctx), beneficiary);

    transfer::public_transfer(coin.split(admin_fee_amount, ctx), @memez_treasury);  
}

fun revenue(id: &UID): &Revenue {
    df::borrow(id, RevenueKey())
}

fun revenue_mut(id: &mut UID): &mut Revenue {
    df::borrow_mut(id, RevenueKey())
}