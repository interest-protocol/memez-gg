// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

module memez_fun::memez_constant_product;

use constant_product::constant_product::get_amount_out;
use ipx_coin_standard::ipx_coin_standard::IPXTreasuryStandard;
use memez_fun::{
    memez_burner::{Self, MemezBurner},
    memez_events,
    memez_fees::Fee,
    memez_utils::{assert_slippage, assert_coin_has_value}
};
use sui::{balance::{Self, Balance}, coin::Coin};

// === Structs ===

public struct MemezConstantProduct<phantom Meme, phantom Quote> has store {
    memez_fun: address,
    virtual_liquidity: u64,
    target_quote_liquidity: u64,
    quote_balance: Balance<Quote>,
    meme_balance: Balance<Meme>,
    burner: MemezBurner,
    swap_fee: Fee,
}

// === Public Package Functions ===

public(package) fun new<Meme, Quote>(
    virtual_liquidity: u64,
    target_quote_liquidity: u64,
    meme_balance: Balance<Meme>,
    swap_fee: Fee,
    burn_tax: u64,
): MemezConstantProduct<Meme, Quote> {
    MemezConstantProduct {
        memez_fun: @0x0,
        virtual_liquidity,
        target_quote_liquidity,
        quote_balance: balance::zero(),
        meme_balance,
        burner: memez_burner::new(vector[burn_tax, virtual_liquidity, target_quote_liquidity]),
        swap_fee,
    }
}

public(package) fun set_memez_fun<Meme, Quote>(
    self: &mut MemezConstantProduct<Meme, Quote>,
    memez_fun: address,
) {
    self.memez_fun = memez_fun;
}

public(package) fun pump<Meme, Quote>(
    self: &mut MemezConstantProduct<Meme, Quote>,
    mut quote_coin: Coin<Quote>,
    min_amount_out: u64,
    ctx: &mut TxContext,
): (bool, Coin<Meme>) {
    let swap_fee = self.swap_fee.take(&mut quote_coin, ctx);

    let quote_coin_value = assert_coin_has_value(&quote_coin);

    let meme_balance_value = self.meme_balance.value();

    let meme_coin_value_out = get_amount_out(
        quote_coin_value,
        self.virtual_liquidity + self.quote_balance.value(),
        meme_balance_value,
    );

    assert_slippage(meme_coin_value_out, min_amount_out);

    let meme_coin = self.meme_balance.split(meme_coin_value_out).into_coin(ctx);

    let total_quote_balance = self.quote_balance.join(quote_coin.into_balance());

    memez_events::pump<Meme, Quote>(
        self.memez_fun,
        quote_coin_value,
        meme_coin_value_out,
        swap_fee,
        total_quote_balance,
        self.meme_balance.value(),
        self.virtual_liquidity,
    );

    (total_quote_balance >= self.target_quote_liquidity, meme_coin)
}

public(package) fun dump<Meme, Quote>(
    self: &mut MemezConstantProduct<Meme, Quote>,
    treasury_cap: &mut IPXTreasuryStandard,
    mut meme_coin: Coin<Meme>,
    min_amount_out: u64,
    ctx: &mut TxContext,
): Coin<Quote> {
    let swap_fee = self.swap_fee.take(&mut meme_coin, ctx);

    let meme_coin_value = assert_coin_has_value(&meme_coin);

    let meme_balance_value = self.meme_balance.value();

    let quote_balance_value = self.quote_balance.value();

    let quote_virtual_liquidity = self.virtual_liquidity + quote_balance_value;

    let pre_tax_quote_value_out = get_amount_out(
        meme_coin_value,
        meme_balance_value,
        quote_virtual_liquidity,
    );

    let dynamic_burn_tax = self.burner.calculate(quote_virtual_liquidity - pre_tax_quote_value_out);
    let meme_burn_fee_value = dynamic_burn_tax.calc_up(meme_coin_value);

    if (dynamic_burn_tax.value() != 0) treasury_cap.burn(meme_coin.split(meme_burn_fee_value, ctx));

    let meme_coin_value = assert_coin_has_value(&meme_coin);

    let quote_value_out = get_amount_out(
        meme_coin_value,
        meme_balance_value,
        quote_virtual_liquidity,
    );

    self.meme_balance.join(meme_coin.into_balance());

    let quote_coin_amount_out = quote_value_out.min(quote_balance_value);

    assert_slippage(quote_coin_amount_out, min_amount_out);

    let quote_coin = self.quote_balance.split(quote_coin_amount_out).into_coin(ctx);

    memez_events::dump<Meme, Quote>(
        self.memez_fun,
        meme_coin_value,
        quote_coin_amount_out,
        swap_fee,
        meme_burn_fee_value,
        self.quote_balance.value(),
        self.meme_balance.value(),
        self.virtual_liquidity,
    );

    quote_coin
}

public(package) fun pump_amount<Meme, Quote>(
    self: &MemezConstantProduct<Meme, Quote>,
    amount_in: u64,
    extra_meme_amount: u64,
): vector<u64> {
    if (amount_in == 0) return vector[0, 0];

    let swap_fee = self.swap_fee.calculate(amount_in);

    let amount_out = get_amount_out(
        amount_in - swap_fee,
        self.virtual_liquidity + self.quote_balance.value(),
        self.meme_balance.value() + extra_meme_amount,
    );

    vector[amount_out, swap_fee]
}

public(package) fun dump_amount<Meme, Quote>(
    self: &MemezConstantProduct<Meme, Quote>,
    amount_in: u64,
    extra_meme_amount: u64,
): vector<u64> {
    if (amount_in == 0) return vector[0, 0, 0, 0];

    let meme_balance_value = self.meme_balance.value() + extra_meme_amount;

    let quote_balance_value = self.quote_balance.value();

    let quote_virtual_liquidity = self.virtual_liquidity + quote_balance_value;

    let swap_fee = self.swap_fee.calculate(amount_in);

    let amount_in_minus_swap_fee = amount_in - swap_fee;

    let pre_tax_quote_value_out = get_amount_out(
        amount_in_minus_swap_fee,
        meme_balance_value,
        quote_virtual_liquidity,
    );

    let dynamic_burn_tax = self.burner.calculate(quote_virtual_liquidity - pre_tax_quote_value_out);

    if (dynamic_burn_tax.value() == 0) {
        return vector[
            pre_tax_quote_value_out.min(quote_balance_value),
            pre_tax_quote_value_out,
            swap_fee,
            0,
        ]
    };

    let meme_burn_fee_value = dynamic_burn_tax.calc_up(amount_in_minus_swap_fee);

    let post_tax_quote_value_out = get_amount_out(
        amount_in_minus_swap_fee - meme_burn_fee_value,
        meme_balance_value,
        quote_virtual_liquidity,
    );

    vector[
        post_tax_quote_value_out.min(quote_balance_value),
        post_tax_quote_value_out,
        swap_fee,
        meme_burn_fee_value,
    ]
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

// === Test Only Functions ===

#[test_only]
public fun memez_fun<Meme, Quote>(self: &MemezConstantProduct<Meme, Quote>): address {
    self.memez_fun
}

#[test_only]
public fun swap_fee<Meme, Quote>(self: &MemezConstantProduct<Meme, Quote>): Fee {
    self.swap_fee
}
