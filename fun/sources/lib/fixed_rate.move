module memez_fun::memez_fixed_rate;

use interest_math::u64;
use memez_fun::{memez_events, memez_utils::{assert_slippage, assert_coin_has_value}};
use sui::{balance::{Self, Balance}, coin::{Self, Coin}, sui::SUI};

// === Structs ===

public struct FixedRate<phantom Meme> has store {
    memez_fun: address,
    sui_raise_amount: u64,
    meme_sale_amount: u64,
    sui_balance: Balance<SUI>,
    meme_balance: Balance<Meme>,
}

// === Public Package Functions ===

public(package) fun new<Meme>(sui_raise_amount: u64, meme_balance: Balance<Meme>): FixedRate<Meme> {
    let meme_sale_amount = meme_balance.value();
    FixedRate {
        memez_fun: @0x0,
        sui_raise_amount,
        meme_sale_amount,
        sui_balance: balance::zero(),
        meme_balance,
    }
}

public(package) fun set_memez_fun<Meme>(self: &mut FixedRate<Meme>, memez_fun: address) {
    self.memez_fun = memez_fun;
}

public(package) fun pump<Meme>(
    self: &mut FixedRate<Meme>,
    mut sui_coin: Coin<SUI>,
    min_amount_out: u64,
    ctx: &mut TxContext,
): (bool, Coin<SUI>, Coin<Meme>) {
    let sui_coin_value = assert_coin_has_value(&sui_coin);

    let sui_amount_left = self.sui_raise_amount - self.sui_balance.value();

    let excess_sui_coin = if (sui_coin_value > sui_amount_left) {
        sui_coin.split(sui_coin_value - sui_amount_left, ctx)
    } else coin::zero(ctx);

    let sui_coin_value = sui_coin.value();

    let meme_coin_value_out = u64::min(
        self.meme_balance.value(),
        u64::mul_div_down(sui_coin_value, self.meme_sale_amount, self.sui_raise_amount),
    );

    assert_slippage(meme_coin_value_out, min_amount_out);

    let meme_coin = self.meme_balance.split(meme_coin_value_out).into_coin(ctx);

    let total_sui_balance = self.sui_balance.join(sui_coin.into_balance());

    memez_events::pump<Meme>(self.memez_fun, sui_coin_value, meme_coin_value_out);

    (total_sui_balance >= self.sui_raise_amount, excess_sui_coin, meme_coin)
}

public(package) fun dump<Meme>(
    self: &mut FixedRate<Meme>,
    meme_coin: Coin<Meme>,
    min_amount_out: u64,
    ctx: &mut TxContext,
): Coin<SUI> {
    let meme_coin_value = assert_coin_has_value(&meme_coin);

    let sui_coin_value_out = u64::min(
        self.sui_balance.value(),
        u64::mul_div_down(meme_coin_value, self.sui_raise_amount, self.meme_sale_amount),
    );

    assert_slippage(sui_coin_value_out, min_amount_out);

    self.meme_balance.join(meme_coin.into_balance());

    let sui_coin = self.sui_balance.split(sui_coin_value_out).into_coin(ctx);

    memez_events::dump<Meme>(
        self.memez_fun,
        sui_coin_value_out,
        meme_coin_value,
        0,
    );

    sui_coin
}

public(package) fun pump_amount<Meme>(self: &FixedRate<Meme>, sui_amount: u64): (u64, u64) {
    if (sui_amount == 0) return (0, 0);

    if (self.sui_balance.value() >= self.sui_raise_amount) return (sui_amount, 0);

    let sui_amount_left = self.sui_raise_amount - self.sui_balance.value();

    let excess_sui_amount = if (sui_amount > sui_amount_left) sui_amount - sui_amount_left
    else 0;

    let sui_coin_value = sui_amount - excess_sui_amount;

    let meme_coin_value_out = u64::min(
        self.meme_balance.value(),
        u64::mul_div_down(sui_coin_value, self.meme_sale_amount, self.sui_raise_amount),
    );

    (excess_sui_amount, meme_coin_value_out)
}

public(package) fun dump_amount<Meme>(self: &FixedRate<Meme>, meme_amount: u64): u64 {
    if (meme_amount == 0) return 0;
    u64::min(
        self.sui_balance.value(),
        u64::mul_div_down(meme_amount, self.sui_raise_amount, self.meme_sale_amount),
    )
}

public(package) fun sui_balance<Meme>(self: &FixedRate<Meme>): &Balance<SUI> {
    &self.sui_balance
}

public(package) fun meme_balance<Meme>(self: &FixedRate<Meme>): &Balance<Meme> {
    &self.meme_balance
}

public(package) fun sui_balance_mut<Meme>(self: &mut FixedRate<Meme>): &mut Balance<SUI> {
    &mut self.sui_balance
}

public(package) fun meme_balance_mut<Meme>(self: &mut FixedRate<Meme>): &mut Balance<Meme> {
    &mut self.meme_balance
}

public(package) fun sui_raise_amount<Meme>(self: &FixedRate<Meme>): u64 {
    self.sui_raise_amount
}

public(package) fun meme_sale_amount<Meme>(self: &FixedRate<Meme>): u64 {
    self.meme_sale_amount
}

// === Test Only Functions ===

#[test_only]
public fun memez_fun<Meme>(self: &FixedRate<Meme>): address {
    self.memez_fun
}
