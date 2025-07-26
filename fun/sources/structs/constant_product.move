// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

module memez_fun::memez_constant_product;

use interest_bps::bps::BPS;
use interest_constant_product::constant_product::get_amount_out;
use ipx_coin_standard::ipx_coin_standard::IPXTreasuryStandard;
use memez_fun::{memez_burner::{Self, MemezBurner}, memez_events, memez_fees::Fee};
use sui::{balance::{Self, Balance}, coin::Coin};

// === Structs ===

public struct MemezConstantProduct<phantom Meme, phantom Quote> has store {
    memez_fun: address,
    inner_state: address,
    virtual_liquidity: u64,
    target_quote_liquidity: u64,
    quote_balance: Balance<Quote>,
    meme_balance: Balance<Meme>,
    burner: MemezBurner,
    meme_swap_fee: Fee,
    quote_swap_fee: Fee,
    meme_referrer_fee: BPS,
    quote_referrer_fee: BPS,
}

// === Public Package Functions ===

public(package) fun new<Meme, Quote>(
    virtual_liquidity: u64,
    target_quote_liquidity: u64,
    meme_balance: Balance<Meme>,
    meme_swap_fee: Fee,
    quote_swap_fee: Fee,
    meme_referrer_fee: BPS,
    quote_referrer_fee: BPS,
    burn_tax: u64,
): MemezConstantProduct<Meme, Quote> {
    MemezConstantProduct {
        memez_fun: @0x0,
        inner_state: @0x0,
        virtual_liquidity,
        target_quote_liquidity,
        quote_balance: balance::zero(),
        meme_balance,
        burner: memez_burner::new(burn_tax, target_quote_liquidity),
        meme_swap_fee,
        quote_swap_fee,
        meme_referrer_fee,
        quote_referrer_fee,
    }
}

public(package) fun set_memez_fun<Meme, Quote>(
    self: &mut MemezConstantProduct<Meme, Quote>,
    memez_fun: address,
) {
    self.memez_fun = memez_fun;
}

public(package) fun set_inner_state<Meme, Quote>(
    self: &mut MemezConstantProduct<Meme, Quote>,
    inner_state: address,
) {
    self.inner_state = inner_state;
}

public(package) fun inner_state<Meme, Quote>(self: &MemezConstantProduct<Meme, Quote>): address {
    self.inner_state
}

public(package) fun pump<Meme, Quote>(
    self: &mut MemezConstantProduct<Meme, Quote>,
    mut quote_coin: Coin<Quote>,
    referrer: Option<address>,
    min_amount_out: u64,
    ctx: &mut TxContext,
): (bool, Coin<Meme>) {
    let quote_referrer_fee = quote_coin.send_referrer_fee!(referrer, self.quote_referrer_fee, ctx);

    let quote_swap_fee = self
        .quote_swap_fee
        .take_with_discount(&mut quote_coin, self.quote_referrer_fee, ctx);

    let quote_coin_value = quote_coin.assert_has_value!();

    let meme_balance_value = self.meme_balance.value();

    let meme_coin_value_out = get_amount_out!(
        quote_coin_value,
        self.virtual_liquidity + self.quote_balance.value(),
        meme_balance_value,
    );

    let meme_referrer_fee_value = self.meme_referrer_fee.calc_up(meme_coin_value_out);

    let meme_coin_value_out_minus_swap_fee =
        meme_coin_value_out - self.meme_swap_fee.calculate_with_discount(self.meme_referrer_fee, meme_coin_value_out) - meme_referrer_fee_value;

    meme_coin_value_out_minus_swap_fee.assert_slippage!(min_amount_out);

    let mut meme_coin = self.meme_balance.split(meme_coin_value_out).into_coin(ctx);

    let total_quote_balance = self.quote_balance.join(quote_coin.into_balance());

    memez_events::pump<Meme, Quote>(
        self.memez_fun,
        self.inner_state,
        quote_coin_value + quote_swap_fee,
        meme_coin_value_out_minus_swap_fee,
        self.meme_swap_fee.take_with_discount(&mut meme_coin, self.meme_referrer_fee, ctx),
        quote_swap_fee,
        total_quote_balance,
        self.meme_balance.value(),
        self.virtual_liquidity,
        referrer,
        meme_coin.send_referrer_fee!(referrer, self.meme_referrer_fee, ctx),
        quote_referrer_fee,
    );

    (total_quote_balance >= self.target_quote_liquidity, meme_coin)
}

public(package) fun dump<Meme, Quote>(
    self: &mut MemezConstantProduct<Meme, Quote>,
    treasury_cap: &mut IPXTreasuryStandard,
    mut meme_coin: Coin<Meme>,
    referrer: Option<address>,
    min_amount_out: u64,
    ctx: &mut TxContext,
): Coin<Quote> {
    let meme_referrer_fee_value = meme_coin.send_referrer_fee!(
        referrer,
        self.meme_referrer_fee,
        ctx,
    );

    let meme_swap_fee = self
        .meme_swap_fee
        .take_with_discount(&mut meme_coin, self.meme_referrer_fee, ctx);

    let meme_coin_value = meme_coin.assert_has_value!();

    let meme_balance_value = self.meme_balance.value();

    let quote_balance_value = self.quote_balance.value();

    let dynamic_burn_tax = self.burner.calculate(quote_balance_value);
    let meme_burn_fee_value = dynamic_burn_tax.calc_up(meme_coin_value);

    if (dynamic_burn_tax.value() != 0) treasury_cap.burn(meme_coin.split(meme_burn_fee_value, ctx));

    let meme_coin_value = meme_coin.assert_has_value!();

    let quote_value_out = get_amount_out!(
        meme_coin_value,
        meme_balance_value,
        self.virtual_liquidity + quote_balance_value,
    );

    self.meme_balance.join(meme_coin.into_balance());

    let quote_coin_amount_out = quote_value_out.min(quote_balance_value);

    let quote_referrer_fee_value = self.quote_referrer_fee.calc_up(quote_coin_amount_out);

    let quote_coin_value_out_minus_swap_fee =
        quote_coin_amount_out - self.quote_swap_fee.calculate_with_discount(self.quote_referrer_fee, quote_coin_amount_out) - quote_referrer_fee_value;

    quote_coin_value_out_minus_swap_fee.assert_slippage!(min_amount_out);

    let mut quote_coin = self.quote_balance.split(quote_coin_amount_out).into_coin(ctx);

    memez_events::dump<Meme, Quote>(
        self.memez_fun,
        self.inner_state,
        meme_coin_value + meme_swap_fee,
        quote_coin_value_out_minus_swap_fee,
        meme_swap_fee,
        self.quote_swap_fee.take_with_discount(&mut quote_coin, self.quote_referrer_fee, ctx),
        meme_burn_fee_value,
        self.quote_balance.value(),
        self.meme_balance.value(),
        self.virtual_liquidity,
        referrer,
        meme_referrer_fee_value,
        quote_coin.send_referrer_fee!(referrer, self.quote_referrer_fee, ctx),
    );

    quote_coin
}

public(package) fun pump_amount<Meme, Quote>(
    self: &MemezConstantProduct<Meme, Quote>,
    amount_in: u64,
): vector<u64> {
    if (amount_in == 0) return vector[0, 0, 0];

    let quote_swap_fee =
        self.quote_swap_fee.calculate_with_discount(self.quote_referrer_fee, amount_in) + self.quote_referrer_fee.calc_up(amount_in);

    let amount_out = get_amount_out!(
        amount_in - quote_swap_fee,
        self.virtual_liquidity + self.quote_balance.value(),
        self.meme_balance.value(),
    );

    let meme_swap_fee =
        self.meme_swap_fee.calculate_with_discount(self.meme_referrer_fee, amount_out) + self.meme_referrer_fee.calc_up(amount_out);

    vector[amount_out - meme_swap_fee, quote_swap_fee, meme_swap_fee]
}

public(package) fun dump_amount<Meme, Quote>(
    self: &MemezConstantProduct<Meme, Quote>,
    amount_in: u64,
): vector<u64> {
    if (amount_in == 0) return vector[0, 0, 0, 0];

    let meme_balance_value = self.meme_balance.value();

    let quote_balance_value = self.quote_balance.value();

    let meme_swap_fee =
        self.meme_swap_fee.calculate_with_discount(self.meme_referrer_fee, amount_in) + self.meme_referrer_fee.calc_up(amount_in);

    let amount_in_minus_swap_fee = amount_in - meme_swap_fee;

    let dynamic_burn_tax = self.burner.calculate(quote_balance_value);

    let meme_burn_fee_value = dynamic_burn_tax.calc_up(amount_in_minus_swap_fee);

    let quote_value_out = get_amount_out!(
        amount_in_minus_swap_fee - meme_burn_fee_value,
        meme_balance_value,
        self.virtual_liquidity + quote_balance_value,
    );

    let safe_value_out = quote_value_out.min(quote_balance_value);

    let quote_swap_fee =
        self.quote_swap_fee.calculate_with_discount(self.quote_referrer_fee, safe_value_out) + self.quote_referrer_fee.calc_up(safe_value_out);

    vector[safe_value_out - quote_swap_fee, meme_swap_fee, meme_burn_fee_value, quote_swap_fee]
}

public(package) fun virtual_liquidity<Meme, Quote>(self: &MemezConstantProduct<Meme, Quote>): u64 {
    self.virtual_liquidity
}

public(package) fun target_quote_liquidity<Meme, Quote>(
    self: &MemezConstantProduct<Meme, Quote>,
): u64 {
    self.target_quote_liquidity
}

public(package) fun quote_balance<Meme, Quote>(
    self: &MemezConstantProduct<Meme, Quote>,
): &Balance<Quote> {
    &self.quote_balance
}

public(package) fun burner<Meme, Quote>(self: &MemezConstantProduct<Meme, Quote>): MemezBurner {
    self.burner
}

public(package) fun meme_balance<Meme, Quote>(
    self: &MemezConstantProduct<Meme, Quote>,
): &Balance<Meme> {
    &self.meme_balance
}

public(package) fun quote_balance_mut<Meme, Quote>(
    self: &mut MemezConstantProduct<Meme, Quote>,
): &mut Balance<Quote> {
    &mut self.quote_balance
}

public(package) fun meme_balance_mut<Meme, Quote>(
    self: &mut MemezConstantProduct<Meme, Quote>,
): &mut Balance<Meme> {
    &mut self.meme_balance
}

// === Aliases ===

use fun memez_fun::memez_utils::assert_slippage as u64.assert_slippage;
use fun memez_fun::memez_utils::send_referrer_fee as Coin.send_referrer_fee;
use fun memez_fun::memez_utils::assert_coin_has_value as Coin.assert_has_value;

// === Test Only Functions ===

#[test_only]
public fun memez_fun<Meme, Quote>(self: &MemezConstantProduct<Meme, Quote>): address {
    self.memez_fun
}

#[test_only]
public fun meme_swap_fee<Meme, Quote>(self: &MemezConstantProduct<Meme, Quote>): Fee {
    self.meme_swap_fee
}

#[test_only]
public fun quote_swap_fee<Meme, Quote>(self: &MemezConstantProduct<Meme, Quote>): Fee {
    self.quote_swap_fee
}

#[test_only]
public fun meme_referrer_fee<Meme, Quote>(self: &MemezConstantProduct<Meme, Quote>): BPS {
    self.meme_referrer_fee
}

#[test_only]
public fun quote_referrer_fee<Meme, Quote>(self: &MemezConstantProduct<Meme, Quote>): BPS {
    self.quote_referrer_fee
}
