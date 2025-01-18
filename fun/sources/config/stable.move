// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

module memez_fun::memez_stable_config;

use interest_bps::bps::{Self, BPS};
use memez_fun::memez_errors;
use std::type_name::{Self, TypeName};

// === Constants ===

const VALUES_LENGTH: u64 = 3;

// === Structs ===

public struct StableConfig has copy, drop, store {
    max_target_quote_liquidity: u64,
    liquidity_provision: BPS,
    meme_sale_amount: BPS,
    quote_type: TypeName,
}

// === Public Package Functions ===

public(package) fun new<Quote>(values: vector<u64>): StableConfig {
    assert!(values.length() == VALUES_LENGTH, memez_errors::invalid_config!());

    StableConfig {
        max_target_quote_liquidity: values[0],
        liquidity_provision: bps::new(values[1]),
        meme_sale_amount: bps::new(values[2]),
        quote_type: type_name::get<Quote>(),
    }
}

public(package) fun get<Quote>(self: &StableConfig, total_supply: u64): vector<u64> {
    assert!(type_name::get<Quote>() == self.quote_type, memez_errors::invalid_quote_type!());

    let liquidity_provision = self.liquidity_provision.calc(total_supply);

    let meme_sale_amount = self.meme_sale_amount.calc(total_supply);

    vector[self.max_target_quote_liquidity, liquidity_provision, meme_sale_amount]
}

// === Test Only Functions ===

#[test_only]
public fun quote_type(self: &StableConfig): TypeName {
    self.quote_type
}
