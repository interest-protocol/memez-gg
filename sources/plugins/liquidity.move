module memez_gg::liquidity;
// === Imports ===

use std::type_name;

use sui::{
    sui::SUI,
    coin::{Self, Coin},
    dynamic_field as df,
    balance::{Self, Balance}
};

use memez_gg::fees;

// === Constants ===

// @dev Only beef up the liquidity once we have stored 20 Sui. 
const LIQUIDITY_EVENT_THRESHOLD: u64 = 20__000_000_000;

// === Errors ===

#[error]
const InvalidLiquidityFee: vector<u8> = b"The maximum liquidity fee is 5%";

// === Structs ===

public struct LiquidityKey() has store, copy, drop;

public struct Liquidity<phantom CoinType> has store {
    fee: u64,
    balance: Balance<CoinType>
}

// === Public Package Functions === 

public(package) fun new(id: &mut UID, fee: u64) {
    assert!(fees::max_liquidity_fee() >= fee, InvalidLiquidityFee);

    let liquidity = Liquidity {
        fee,
        balance: balance::zero<SUI>()
    };

    df::add(id, LiquidityKey(), liquidity);
}

public(package) fun supports(id: &UID): bool {
    df::exists_(id, LiquidityKey())
}

public(package) fun fee<CoinType>(id: &UID): u64 {
    if (!supports(id)) return 0;

    let liquidity = liquidity<CoinType>(id);

    liquidity.fee
}

public(package) fun take<CoinType>(id: &mut UID, coin: &mut Coin<CoinType>, ctx: &mut TxContext) {
    if (!supports(id) || type_name::get<SUI>() != type_name::get<CoinType>()) return;

    let liquidity = liquidity_mut(id);

    let fee_amount = fees::calculate(coin.value(), liquidity.fee);

    liquidity.balance.join(coin.split(fee_amount, ctx).into_balance());
}

public(package) fun start(id: &mut UID, ctx: &mut TxContext): Coin<SUI> {
    if (!supports(id)) return coin::zero(ctx);

    let liquidity = liquidity_mut<SUI>(id);

    if (LIQUIDITY_EVENT_THRESHOLD >=liquidity.balance.value()) return coin::zero(ctx);

    liquidity.balance.withdraw_all().into_coin(ctx)
}

// === Private Functions === 

fun liquidity<CoinType>(id: &UID): &Liquidity<CoinType> {
    df::borrow(id, LiquidityKey())
}

fun liquidity_mut<CoinType>(id: &mut UID): &mut Liquidity<CoinType> {
    df::borrow_mut(id, LiquidityKey())
}