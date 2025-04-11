// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

module memez_fun::memez_stable_config;

use interest_bps::bps::{Self, BPS};

// === Constants ===

const VALUES_LENGTH: u64 = 3;

// === Structs ===

public struct StableConfig has copy, drop, store {
    target_quote_liquidity: u64,
    liquidity_provision: BPS,
    meme_sale_amount: BPS,
}

// === Public Functions ===

public fun new(values: vector<u64>): StableConfig {
    assert_values(values);

    StableConfig {
        target_quote_liquidity: values[0],
        liquidity_provision: bps::new(values[1]),
        meme_sale_amount: bps::new(values[2]),
    }
}

// === Public Package Functions ===

public(package) fun target_quote_liquidity(self: &StableConfig): u64 {
    self.target_quote_liquidity
}

public(package) fun liquidity_provision(self: &StableConfig, total_supply: u64): u64 {
    self.liquidity_provision.calc(total_supply)
}

public(package) fun meme_sale_amount(self: &StableConfig, total_supply: u64): u64 {
    self.meme_sale_amount.calc(total_supply)
}

// === Private Functions ===

fun assert_values(values: vector<u64>) {
    assert!(values.length() == VALUES_LENGTH, memez_fun::memez_errors::invalid_config!());
    assert!(values[0] != 0);
    assert!(values[1] != 0);
    assert!(values[2] != 0);
}
