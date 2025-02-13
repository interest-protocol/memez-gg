// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

module memez_fun::memez_pump_config;

use interest_bps::bps::{Self, BPS};
use memez_fun::memez_errors;
use std::type_name::{Self, TypeName};

// === Constants ===

const VALUES_LENGTH: u64 = 4;

// === Structs ===

public struct PumpConfig has copy, drop, store {
    burn_tax: u64,
    virtual_liquidity: u64,
    target_quote_liquidity: u64,
    liquidity_provision: BPS,
    quote_type: TypeName,
}

// === Public Package Functions ===

public(package) fun new<Quote>(values: vector<u64>): PumpConfig {
    assert_values(values);

    PumpConfig {
        burn_tax: values[0],
        virtual_liquidity: values[1],
        target_quote_liquidity: values[2],
        liquidity_provision: bps::new(values[3]),
        quote_type: type_name::get<Quote>(),
    }
}

public(package) fun get<Quote>(self: &PumpConfig, total_supply: u64): vector<u64> {
    assert!(type_name::get<Quote>() == self.quote_type, memez_errors::invalid_quote_type!());

    let liquidity_provision = self.liquidity_provision.calc(total_supply);

    vector[self.burn_tax, self.virtual_liquidity, self.target_quote_liquidity, liquidity_provision]
}

// === Private Functions ===

fun assert_values(values: vector<u64>) {
    assert!(values.length() == VALUES_LENGTH, memez_errors::invalid_config!());
    assert!(values[1] != 0);
    assert!(values[2] != 0);
}

// === Test Only Functions ===

#[test_only]
public fun quote_type(self: &PumpConfig): TypeName {
    self.quote_type
}
