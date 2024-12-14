module memez_fun::memez_auction_config;

use interest_bps::bps::{Self, BPS};
use memez_fun::memez_errors;

// === Constants ===

const MIN_SEED_LIQUIDITY: u64 = 100;

const VALUES_LENGTH: u64 = 6;

// === Structs ===

public struct AuctionConfig has copy, drop, store {
    auction_duration: u64,
    burn_tax: u64,
    virtual_liquidity: u64,
    target_sui_liquidity: u64,
    liquidity_provision: BPS,
    seed_liquidity: BPS,
}

// === Public Package Functions ===

public(package) fun new(values: vector<u64>): AuctionConfig {
    assert!(values.length() == VALUES_LENGTH, memez_errors::invalid_config());

    AuctionConfig {
        auction_duration: values[0],
        burn_tax: values[1],
        virtual_liquidity: values[2],
        target_sui_liquidity: values[3],
        liquidity_provision: bps::new(values[4]),
        seed_liquidity: bps::new(values[5]),
    }
}

public(package) fun get(self: &AuctionConfig, total_supply: u64): vector<u64> {
    let liquidity_provision = self.liquidity_provision.calc(total_supply);
    let seed_liquidity = self.seed_liquidity.calc(total_supply).max(MIN_SEED_LIQUIDITY);

    vector[
        self.auction_duration,
        self.burn_tax,
        self.virtual_liquidity,
        self.target_sui_liquidity,
        liquidity_provision,
        seed_liquidity,
    ]
}
