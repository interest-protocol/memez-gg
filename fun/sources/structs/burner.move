module memez_fun::memez_burner;

use interest_math::u64;
use memez_fun::{memez_errors, memez_utils::pow_9};

// === Constants ===

const VALUES_LENGTH: u64 = 3;

// === Structs ===

public struct MemezBurner has copy, drop, store {
    value: u64,
    start_liquidity: u64,
    target_liquidity: u64,
}

// === Public Package Functions ===

public(package) fun new(values: vector<u64>): MemezBurner {
    assert!(values.length() == VALUES_LENGTH, memez_errors::invalid_model_config());

    MemezBurner {
        value: values[0],
        start_liquidity: values[1],
        target_liquidity: values[2],
    }
}

public(package) fun zero(): MemezBurner {
    MemezBurner {
        value: 0,
        start_liquidity: 0,
        target_liquidity: 0,
    }
}

public(package) fun calculate(self: MemezBurner, liquidity: u64): u64 {
    if (self.value == 0 || liquidity >= self.target_liquidity) return 0;

    if (self.start_liquidity >= liquidity) return self.value;

    let total_range = self.target_liquidity - self.start_liquidity;

    let progress = liquidity - self.start_liquidity;

    let pow_9 = pow_9();

    let remaining_percentage = u64::mul_div_down(total_range - progress, pow_9, total_range);

    u64::mul_div_up(self.value, remaining_percentage, pow_9)
}

// === Test Only ===

#[test_only]
public fun value(self: MemezBurner): u64 {
    self.value
}

#[test_only]
public fun start_liquidity(self: MemezBurner): u64 {
    self.start_liquidity
}

#[test_only]
public fun target_liquidity(self: MemezBurner): u64 {
    self.target_liquidity
}
