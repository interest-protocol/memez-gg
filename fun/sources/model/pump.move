module memez_fun::memez_pump_model;

use interest_bps::bps::{Self, BPS};
use memez_fun::memez_errors;

// === Constants ===

const VALUES_LENGTH: u64 = 6;

// === Structs ===

public struct PumpModel has copy, drop, store {
    burn_tax: u64,
    virtual_liquidity: u64,
    target_sui_liquidity: u64,
    liquidity_provision: BPS,
    dev_allocation: BPS,
    dev_vesting_period: u64,
}

// === Public Package Functions ===

public(package) fun new(values: vector<u64>): PumpModel {
    assert!(values.length() == VALUES_LENGTH, memez_errors::invalid_config());

    PumpModel {
        burn_tax: values[0],
        virtual_liquidity: values[1],
        target_sui_liquidity: values[2],
        liquidity_provision: bps::new(values[3]),
        dev_allocation: bps::new(values[4]),
        dev_vesting_period: values[5],
    }
}

public(package) fun get(self: &PumpModel, total_supply: u64): vector<u64> {
    let liquidity_provision = self.liquidity_provision.calc(total_supply);

    let dev_allocation = self.dev_allocation.calc(total_supply);

    vector[
        self.burn_tax,
        self.virtual_liquidity,
        self.target_sui_liquidity,
        liquidity_provision,
        dev_allocation,
        self.dev_vesting_period,
    ]
}
