module memez_fun::memez_stable_model;

use interest_bps::bps::{Self, BPS};
use memez_fun::memez_errors;

// === Constants ===

const VALUES_LENGTH: u64 = 3;

// === Structs ===

public struct StableModel has copy, drop, store {
    max_target_sui_liquidity: u64,
    liquidity_provision: BPS,
    meme_sale_amount: BPS,
}

// === Public Package Functions ===

public(package) fun new(values: vector<u64>): StableModel {
    assert!(values.length() == VALUES_LENGTH, memez_errors::invalid_config());

    StableModel {
        max_target_sui_liquidity: values[0],
        liquidity_provision: bps::new(values[1]),
        meme_sale_amount: bps::new(values[2]),
    }
}

public(package) fun get(self: &StableModel, total_supply: u64): vector<u64> {
    let liquidity_provision = self.liquidity_provision.calc(total_supply);

    let meme_sale_amount = self.meme_sale_amount.calc(total_supply);

    vector[self.max_target_sui_liquidity, liquidity_provision, meme_sale_amount]
}
