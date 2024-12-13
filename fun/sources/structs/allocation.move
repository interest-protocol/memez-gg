module memez_fun::memez_allocation_model;

use interest_bps::bps::{Self, BPS};
use memez_fun::memez_errors;

// === Constants ===

const MIN_SEED_LIQUIDITY: u64 = 100;

const VALUES_LENGTH: u64 = 7;

// === Structs ===

public struct AuctionModel has copy, drop, store {
    auction_duration: u64,
    dev_allocation: BPS,
    burn_tax: u64,
    virtual_liquidity: u64,
    target_sui_liquidity: u64,
    liquidity_provision: BPS,
    seed_liquidity: BPS,
}

// === Public Package Functions ===

public(package) fun new(values: vector<u64>): AuctionModel {
    assert!(values.length() == VALUES_LENGTH, memez_errors::invalid_config());

    AuctionModel {
        auction_duration: values[0],
        dev_allocation: bps::new(values[1]),
        burn_tax: values[2],
        virtual_liquidity: values[3],
        target_sui_liquidity: values[4],
        liquidity_provision: bps::new(values[5]),
        seed_liquidity: bps::new(values[6]),
    }
}

public(package) fun get(self: &AuctionModel, total_supply: u64): vector<u64> {
    let dev_allocation = self.dev_allocation.calc(total_supply);
    let liquidity_provision = self.liquidity_provision.calc(total_supply);
    let seed_liquidity = self.seed_liquidity.calc(total_supply).max(MIN_SEED_LIQUIDITY);

    vector[
        self.auction_duration,
        dev_allocation,
        self.burn_tax,
        self.virtual_liquidity,
        self.target_sui_liquidity,
        liquidity_provision,
        seed_liquidity,
    ]
}