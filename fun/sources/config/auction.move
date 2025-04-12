// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

module memez_fun::memez_auction_config;

use interest_bps::bps::{Self, BPS};

// === Constants ===

const MIN_SEED_LIQUIDITY: u64 = 100;

const VALUES_LENGTH: u64 = 5;

// === Structs ===

public struct AuctionConfig has copy, drop, store {
    auction_duration: u64,
    target_quote_liquidity: u64,
    liquidity_provision: BPS,
    seed_liquidity: BPS,
    total_supply: u64,
}

// === Public Functions ===

public fun new(values: vector<u64>): AuctionConfig {
    assert_values(values);

    AuctionConfig {
        auction_duration: values[0],
        target_quote_liquidity: values[1],
        liquidity_provision: bps::new(values[2]),
        seed_liquidity: bps::new(values[3]),
        total_supply: values[4],
    }
}

// === Public Package Functions ===

public(package) fun auction_duration(self: &AuctionConfig): u64 {
    self.auction_duration
}

public(package) fun target_quote_liquidity(self: &AuctionConfig): u64 {
    self.target_quote_liquidity
}

public(package) fun liquidity_provision(self: &AuctionConfig): u64 {
    self.liquidity_provision.calc(self.total_supply)
}

public(package) fun seed_liquidity(self: &AuctionConfig): u64 {
    self.seed_liquidity.calc(self.total_supply).max(MIN_SEED_LIQUIDITY)
}

public(package) fun total_supply(self: &AuctionConfig): u64 {
    self.total_supply
}

// === Private Functions ===

fun assert_values(values: vector<u64>) {
    assert!(values.length() == VALUES_LENGTH, memez_fun::memez_errors::invalid_config!());
    assert!(values[0] != 0);
    assert!(values[1] != 0);
    assert!(values[2] != 0);
    assert!(values[3] != 0);
    assert!(values[4] != 0);
}
