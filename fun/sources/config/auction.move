// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

module memez_fun::memez_auction_config;

use interest_bps::bps::{Self, BPS};
use memez_fun::memez_errors;
use std::type_name::{Self, TypeName};

// === Constants ===

const MIN_SEED_LIQUIDITY: u64 = 100;

const VALUES_LENGTH: u64 = 6;

// === Structs ===

public struct AuctionConfig has copy, drop, store {
    auction_duration: u64,
    burn_tax: u64,
    virtual_liquidity: u64,
    target_quote_liquidity: u64,
    liquidity_provision: BPS,
    seed_liquidity: BPS,
    quote_type: TypeName,
}

// === Public Package Functions ===

public(package) fun new<Quote>(values: vector<u64>): AuctionConfig {
    assert!(values.length() == VALUES_LENGTH, memez_errors::invalid_config!());

    AuctionConfig {
        auction_duration: values[0],
        burn_tax: values[1],
        virtual_liquidity: values[2],
        target_quote_liquidity: values[3],
        liquidity_provision: bps::new(values[4]),
        seed_liquidity: bps::new(values[5]),
        quote_type: type_name::get<Quote>(),
    }
}

public(package) fun get<Quote>(self: &AuctionConfig, total_supply: u64): vector<u64> {
    assert!(type_name::get<Quote>() == self.quote_type, memez_errors::invalid_quote_type!());

    let liquidity_provision = self.liquidity_provision.calc(total_supply);
    let seed_liquidity = self.seed_liquidity.calc(total_supply).max(MIN_SEED_LIQUIDITY);

    vector[
        self.auction_duration,
        self.burn_tax,
        self.virtual_liquidity,
        self.target_quote_liquidity,
        liquidity_provision,
        seed_liquidity,
    ]
}

// === Test Only Functions === 

#[test_only]
public fun quote_type(self: &AuctionConfig): TypeName {
    self.quote_type
}
