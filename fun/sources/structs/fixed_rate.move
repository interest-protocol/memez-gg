// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

module memez_fun::memez_fixed_rate;

use interest_math::u64;
use memez_fun::{
    memez_events,
    memez_fees::Fee,
    memez_utils::assert_coin_has_value
};
use sui::{balance::{Self, Balance}, coin::{Self, Coin}};

// === Structs ===

public struct FixedRate<phantom Meme, phantom Quote> has store {
    memez_fun: address,
    quote_raise_amount: u64,
    meme_sale_amount: u64,
    swap_fee: Fee,
    meme_balance: Balance<Meme>,
    quote_balance: Balance<Quote>,
}

// === Public Package Functions ===

public(package) fun new<Meme, Quote>(
    quote_raise_amount: u64,
    meme_balance: Balance<Meme>,
    swap_fee: Fee,
): FixedRate<Meme, Quote> {
    let meme_sale_amount = meme_balance.value();
    FixedRate {
        memez_fun: @0x0,
        quote_raise_amount,
        meme_sale_amount,
        meme_balance,
        quote_balance: balance::zero(),
        swap_fee,
    }
}

public(package) fun set_memez_fun<Meme, Quote>(
    self: &mut FixedRate<Meme, Quote>,
    memez_fun: address,
) {
    self.memez_fun = memez_fun;
}

public(package) fun pump<Meme, Quote>(
    self: &mut FixedRate<Meme, Quote>,
    mut quote_coin: Coin<Quote>,
    ctx: &mut TxContext,
): (bool, Coin<Quote>, Coin<Meme>) {
    let swap_fee = self.swap_fee.take(&mut quote_coin, ctx);

    let quote_coin_value = assert_coin_has_value!(&quote_coin);

    let quote_amount_left = self.quote_raise_amount - self.quote_balance.value();

    let excess_quote_coin = if (quote_coin_value > quote_amount_left) {
        quote_coin.split(quote_coin_value - quote_amount_left, ctx)
    } else coin::zero(ctx);

    let quote_coin_value = quote_coin.value();

    let meme_coin_value_out = self
        .meme_balance
        .value()
        .min(
            u64::mul_div_down(quote_coin_value, self.meme_sale_amount, self.quote_raise_amount),
        );

    let meme_coin = self.meme_balance.split(meme_coin_value_out).into_coin(ctx);

    let total_quote_balance = self.quote_balance.join(quote_coin.into_balance());

    memez_events::pump<Meme, Quote>(
        self.memez_fun,
        quote_coin_value,
        meme_coin_value_out,
        swap_fee,
        total_quote_balance,
        self.meme_balance.value(),
        0,
    );

    (total_quote_balance >= self.quote_raise_amount, excess_quote_coin, meme_coin)
}

public(package) fun dump<Meme, Quote>(
    self: &mut FixedRate<Meme, Quote>,
    mut meme_coin: Coin<Meme>,
    ctx: &mut TxContext,
): Coin<Quote> {
    let swap_fee = self.swap_fee.take(&mut meme_coin, ctx);

    let meme_coin_value = assert_coin_has_value!(&meme_coin);

    let quote_coin_value_out = self
        .quote_balance
        .value()
        .min(
            u64::mul_div_down(meme_coin_value, self.quote_raise_amount, self.meme_sale_amount),
        );

    self.meme_balance.join(meme_coin.into_balance());

    let quote_coin = self.quote_balance.split(quote_coin_value_out).into_coin(ctx);

    memez_events::dump<Meme, Quote>(
        self.memez_fun,
        meme_coin_value,
        quote_coin_value_out,
        swap_fee,
        0,
        self.quote_balance.value(),
        self.meme_balance.value(),
        0,
    );

    quote_coin
}

public(package) fun pump_amount<Meme, Quote>(
    self: &FixedRate<Meme, Quote>,
    quote_amount: u64,
): vector<u64> {
    if (quote_amount == 0) return vector[0, 0, 0];

    if (self.quote_balance.value() >= self.quote_raise_amount) return vector[quote_amount, 0, 0];

    let quote_amount_left = self.quote_raise_amount - self.quote_balance.value();

    let excess_quote_amount = if (quote_amount > quote_amount_left) quote_amount - quote_amount_left
    else 0;

    let quote_coin_value = quote_amount - excess_quote_amount;

    let swap_fee = self.swap_fee.calculate(quote_coin_value);

    let meme_coin_value_out = self
        .meme_balance
        .value()
        .min(
            u64::mul_div_down(
                quote_coin_value - swap_fee,
                self.meme_sale_amount,
                self.quote_raise_amount,
            ),
        );

    vector[excess_quote_amount, meme_coin_value_out, swap_fee]
}

public(package) fun dump_amount<Meme, Quote>(
    self: &FixedRate<Meme, Quote>,
    meme_amount: u64,
): vector<u64> {
    if (meme_amount == 0) return vector[0, 0];

    let swap_fee = self.swap_fee.calculate(meme_amount);

    let quote_coin_value_out = self
        .quote_balance
        .value()
        .min(
            u64::mul_div_down(
                meme_amount - swap_fee,
                self.quote_raise_amount,
                self.meme_sale_amount,
            ),
        );

    vector[quote_coin_value_out, swap_fee]
}

public(package) fun quote_balance<Meme, Quote>(self: &FixedRate<Meme, Quote>): &Balance<Quote> {
    &self.quote_balance
}

public(package) fun meme_balance<Meme, Quote>(self: &FixedRate<Meme, Quote>): &Balance<Meme> {
    &self.meme_balance
}

public(package) fun quote_balance_mut<Meme, Quote>(
    self: &mut FixedRate<Meme, Quote>,
): &mut Balance<Quote> {
    &mut self.quote_balance
}

public(package) fun meme_balance_mut<Meme, Quote>(
    self: &mut FixedRate<Meme, Quote>,
): &mut Balance<Meme> {
    &mut self.meme_balance
}

public(package) fun quote_raise_amount<Meme, Quote>(self: &FixedRate<Meme, Quote>): u64 {
    self.quote_raise_amount
}

public(package) fun meme_sale_amount<Meme, Quote>(self: &FixedRate<Meme, Quote>): u64 {
    self.meme_sale_amount
}

// === Test Only Functions ===

#[test_only]
public fun memez_fun<Meme, Quote>(self: &FixedRate<Meme, Quote>): address {
    self.memez_fun
}

#[test_only]
public fun swap_fee<Meme, Quote>(self: &FixedRate<Meme, Quote>): Fee {
    self.swap_fee
}
