// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

module memez_fun::memez_pump_config;

use interest_bps::bps::{Self, BPS};

// === Constants ===

const VALUES_LENGTH: u64 = 4;

const MAX_BURN_TAX: u64 = 6_000;

// === Structs ===

public struct PumpConfig has copy, drop, store {
    burn_tax: u64,
    virtual_liquidity: u64,
    target_quote_liquidity: u64,
    liquidity_provision: BPS,
}

// === Public Functions ===

public fun new(values: vector<u64>): PumpConfig {
    assert_values(values);

    PumpConfig {
        burn_tax: values[0],
        virtual_liquidity: values[1],
        target_quote_liquidity: values[2],
        liquidity_provision: bps::new(values[3]),
    }
}

// === Public Package Functions ===

public(package) fun burn_tax(self: &PumpConfig): u64 {
    self.burn_tax
}

public(package) fun virtual_liquidity(self: &PumpConfig): u64 {
    self.virtual_liquidity
}

public(package) fun target_quote_liquidity(self: &PumpConfig): u64 {
    self.target_quote_liquidity
}

public(package) fun liquidity_provision(self: &PumpConfig, total_supply: u64): u64 {
    self.liquidity_provision.calc(total_supply)
}

// === Private Functions ===

fun assert_values(values: vector<u64>) {
    assert!(values.length() == VALUES_LENGTH, memez_fun::memez_errors::invalid_config!());
    assert!(values[1] != 0);
    assert!(values[2] != 0);

    assert!(values[0] <= MAX_BURN_TAX, memez_fun::memez_errors::invalid_burn_tax!());
}

// === Test Only Functions ===
