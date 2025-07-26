// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

module memez_fun::memez_fixed_rate;

use interest_bps::bps::{Self, BPS};
use interest_math::u64;
use memez_fun::{memez_events, memez_fees::Fee};
use sui::{balance::{Self, Balance}, coin::{Self, Coin}};

// === Structs ===

public struct FixedRate<phantom Meme, phantom Quote> has store {
    memez_fun: address,
    inner_state: address,
    quote_raise_amount: u64,
    meme_sale_amount: u64,
    meme_swap_fee: Fee,
    quote_swap_fee: Fee,
    meme_balance: Balance<Meme>,
    quote_balance: Balance<Quote>,
    meme_referrer_fee: BPS,
    quote_referrer_fee: BPS,
}

// === Public Package Functions ===

public(package) fun new<Meme, Quote>(
    quote_raise_amount: u64,
    meme_balance: Balance<Meme>,
    meme_swap_fee: Fee,
    quote_swap_fee: Fee,
    meme_referrer_fee: BPS,
    quote_referrer_fee: BPS,
): FixedRate<Meme, Quote> {
    assert!(quote_raise_amount != 0);
    let meme_sale_amount = meme_balance.value();
    FixedRate {
        memez_fun: @0x0,
        inner_state: @0x0,
        quote_raise_amount,
        meme_sale_amount,
        meme_balance,
        quote_balance: balance::zero(),
        meme_swap_fee,
        quote_swap_fee,
        meme_referrer_fee,
        quote_referrer_fee,
    }
}

public(package) fun set_memez_fun<Meme, Quote>(
    self: &mut FixedRate<Meme, Quote>,
    memez_fun: address,
) {
    self.memez_fun = memez_fun;
}

public(package) fun set_inner_state<Meme, Quote>(
    self: &mut FixedRate<Meme, Quote>,
    inner_state: address,
) {
    self.inner_state = inner_state;
}

public(package) fun pump<Meme, Quote>(
    self: &mut FixedRate<Meme, Quote>,
    mut quote_coin: Coin<Quote>,
    referrer: Option<address>,
    ctx: &mut TxContext,
): (bool, Coin<Quote>, Coin<Meme>) {
    let quote_coin_value = quote_coin.assert_has_value!();

    let quote_amount_left = self.quote_raise_amount - self.quote_balance.value();

    let quote_amount_left_before_fee = amount_before_fee(
        quote_amount_left,
        self.quote_swap_fee.value(),
    );

    let excess_quote_coin = if (quote_coin_value > quote_amount_left_before_fee) {
        quote_coin.split(quote_coin_value - quote_amount_left_before_fee, ctx)
    } else coin::zero(ctx);

    let quote_referrer_fee = quote_coin.send_referrer_fee!(referrer, self.quote_referrer_fee, ctx);

    let quote_swap_fee = self
        .quote_swap_fee
        .take_with_discount(&mut quote_coin, self.quote_referrer_fee, ctx);

    let quote_coin_value = quote_coin.value();

    let meme_coin_value_out = self
        .meme_balance
        .value()
        .min(
            u64::mul_div_down(quote_coin_value, self.meme_sale_amount, self.quote_raise_amount),
        );

    let mut meme_coin = self.meme_balance.split(meme_coin_value_out).into_coin(ctx);

    let total_quote_balance = self.quote_balance.join(quote_coin.into_balance());

    let meme_swap_fee = self
        .meme_swap_fee
        .take_with_discount(&mut meme_coin, self.meme_referrer_fee, ctx);

    memez_events::pump<Meme, Quote>(
        self.memez_fun,
        self.inner_state,
        quote_coin_value,
        meme_coin_value_out - meme_swap_fee,
        meme_swap_fee,
        quote_swap_fee,
        total_quote_balance,
        self.meme_balance.value(),
        0,
        referrer,
        meme_coin.send_referrer_fee!(referrer, self.meme_referrer_fee, ctx),
        quote_referrer_fee,
    );

    (total_quote_balance >= self.quote_raise_amount, excess_quote_coin, meme_coin)
}

public(package) fun dump<Meme, Quote>(
    self: &mut FixedRate<Meme, Quote>,
    mut meme_coin: Coin<Meme>,
    referrer: Option<address>,
    ctx: &mut TxContext,
): Coin<Quote> {
    let meme_referrer_fee = meme_coin.send_referrer_fee!(referrer, self.meme_referrer_fee, ctx);

    let meme_swap_fee = self
        .meme_swap_fee
        .take_with_discount(&mut meme_coin, self.meme_referrer_fee, ctx);

    let meme_coin_value = meme_coin.assert_has_value!();

    let quote_coin_value_out = self
        .quote_balance
        .value()
        .min(
            u64::mul_div_down(meme_coin_value, self.quote_raise_amount, self.meme_sale_amount),
        );

    self.meme_balance.join(meme_coin.into_balance());

    let mut quote_coin = self.quote_balance.split(quote_coin_value_out).into_coin(ctx);

    let quote_swap_fee = self
        .quote_swap_fee
        .take_with_discount(&mut quote_coin, self.quote_referrer_fee, ctx);

    memez_events::dump<Meme, Quote>(
        self.memez_fun,
        self.inner_state,
        meme_coin_value + meme_swap_fee,
        quote_coin_value_out - quote_swap_fee,
        meme_swap_fee,
        quote_swap_fee,
        0,
        self.quote_balance.value(),
        self.meme_balance.value(),
        0,
        referrer,
        meme_referrer_fee,
        quote_coin.send_referrer_fee!(referrer, self.quote_referrer_fee, ctx),
    );

    quote_coin
}

public(package) fun pump_amount<Meme, Quote>(
    self: &FixedRate<Meme, Quote>,
    quote_amount: u64,
    extra_meme_sale_amount: u64,
): vector<u64> {
    if (quote_amount == 0) return vector[0, 0, 0, 0];

    if (self.quote_balance.value() >= self.quote_raise_amount) return vector[quote_amount, 0, 0, 0];

    let quote_amount_left = self.quote_raise_amount - self.quote_balance.value();

    let quote_amount_left_before_fee = amount_before_fee(
        quote_amount_left,
        self.quote_swap_fee.value(),
    );

    let excess_quote_amount = if (quote_amount > quote_amount_left_before_fee)
        quote_amount - quote_amount_left_before_fee else 0;

    let quote_coin_value = quote_amount - excess_quote_amount;

    let quote_swap_fee =
        self.quote_swap_fee.calculate_with_discount(self.quote_referrer_fee, quote_coin_value) + self.quote_referrer_fee.calc_up(quote_coin_value);

    let meme_balance_value = self.meme_balance.value() + extra_meme_sale_amount;

    let meme_coin_value_out = meme_balance_value.min(
        u64::mul_div_down(
            quote_coin_value - quote_swap_fee,
            self.meme_sale_amount + extra_meme_sale_amount,
            self.quote_raise_amount,
        ),
    );

    let meme_swap_fee =
        self.meme_swap_fee.calculate_with_discount(self.meme_referrer_fee, meme_coin_value_out) + self.meme_referrer_fee.calc_up(meme_coin_value_out);

    vector[excess_quote_amount, meme_coin_value_out - meme_swap_fee, quote_swap_fee, meme_swap_fee]
}

public(package) fun dump_amount<Meme, Quote>(
    self: &FixedRate<Meme, Quote>,
    meme_amount: u64,
    extra_meme_sale_amount: u64,
): vector<u64> {
    if (meme_amount == 0) return vector[0, 0, 0];

    let meme_swap_fee =
        self.meme_swap_fee.calculate_with_discount(self.meme_referrer_fee, meme_amount) + self.meme_referrer_fee.calc_up(meme_amount);

    let quote_coin_value_out = self
        .quote_balance
        .value()
        .min(
            u64::mul_div_down(
                meme_amount - meme_swap_fee,
                self.quote_raise_amount,
                self.meme_sale_amount + extra_meme_sale_amount,
            ),
        );

    let quote_swap_fee =
        self.quote_swap_fee.calculate_with_discount(self.quote_referrer_fee, quote_coin_value_out) + self.quote_referrer_fee.calc_up(quote_coin_value_out);

    vector[quote_coin_value_out - quote_swap_fee, meme_swap_fee, quote_swap_fee]
}

public(package) fun quote_balance<Meme, Quote>(self: &FixedRate<Meme, Quote>): &Balance<Quote> {
    &self.quote_balance
}

public(package) fun meme_balance<Meme, Quote>(self: &FixedRate<Meme, Quote>): &Balance<Meme> {
    &self.meme_balance
}

//@dev Only to be used in the auction curve.
public(package) fun increase_meme_available<Meme, Quote>(
    self: &mut FixedRate<Meme, Quote>,
    extra_balance: Balance<Meme>,
): u64 {
    self.meme_sale_amount = self.meme_sale_amount + extra_balance.value();
    self.meme_balance.join(extra_balance)
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

// === Private Functions ===

fun amount_before_fee(amount_in: u64, fee: u64): u64 {
    let max_bps = bps::max_value!();
    u64::mul_div_up(amount_in, max_bps, max_bps - fee)
}

// === Aliases ===

use fun memez_fun::memez_utils::send_referrer_fee as Coin.send_referrer_fee;
use fun memez_fun::memez_utils::assert_coin_has_value as Coin.assert_has_value;

// === Test Only Functions ===

#[test_only]
public fun memez_fun<Meme, Quote>(self: &FixedRate<Meme, Quote>): address {
    self.memez_fun
}

#[test_only]
public fun meme_swap_fee<Meme, Quote>(self: &FixedRate<Meme, Quote>): Fee {
    self.meme_swap_fee
}

#[test_only]
public fun quote_swap_fee<Meme, Quote>(self: &FixedRate<Meme, Quote>): Fee {
    self.quote_swap_fee
}

#[test_only]
public fun meme_referrer_fee<Meme, Quote>(self: &FixedRate<Meme, Quote>): BPS {
    self.meme_referrer_fee
}

#[test_only]
public fun quote_referrer_fee<Meme, Quote>(self: &FixedRate<Meme, Quote>): BPS {
    self.quote_referrer_fee
}
