module memez_fun::memez_burner;

use interest_math::u64;
use interest_bps::bps::{Self, max_bps, BPS};
use memez_fun::memez_errors;

// === Constants ===

const VALUES_LENGTH: u64 = 3;

// === Structs ===

public struct MemezBurner has copy, drop, store {
    fee: BPS,
    start_liquidity: u64,
    target_liquidity: u64,
}

// === Public Package Functions ===

public(package) fun new(values: vector<u64>): MemezBurner {
    assert!(values.length() == VALUES_LENGTH, memez_errors::invalid_model_config());

    MemezBurner {
        fee: bps::new(values[0]),
        start_liquidity: values[1],
        target_liquidity: values[2],
    }
}

public(package) fun zero(): MemezBurner {
    MemezBurner {
        fee: bps::new(0),
        start_liquidity: 0,
        target_liquidity: 0,
    }
}

public(package) fun calculate(self: MemezBurner, liquidity: u64): BPS {
    if (self.fee.value() == 0 || liquidity >= self.target_liquidity) return bps::new(0);

    if (self.start_liquidity >= liquidity) return self.fee;

    let total_range = self.target_liquidity - self.start_liquidity;

    let progress = liquidity - self.start_liquidity;

    let max_bps = max_bps();

    let remaining_percentage = u64::mul_div_down(total_range - progress, max_bps, total_range);

    bps::new(u64::mul_div_up(self.fee.value(), remaining_percentage, max_bps))
}

// === Test Only ===

#[test_only]
public fun fee(self: MemezBurner): BPS {
    self.fee
}

#[test_only]
public fun start_liquidity(self: MemezBurner): u64 {
    self.start_liquidity
}

#[test_only]
public fun target_liquidity(self: MemezBurner): u64 {
    self.target_liquidity
}
