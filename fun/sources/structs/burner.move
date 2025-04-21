// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

module memez_fun::memez_burner;

use interest_bps::bps::{Self, BPS};
use interest_math::u64;

// === Structs ===

public struct MemezBurner has copy, drop, store {
    fee: BPS,
    target_liquidity: u64,
}

// === Public Package Functions ===

public(package) fun new(fee: u64, target_liquidity: u64): MemezBurner {
    MemezBurner {
        fee: bps::new(fee),
        target_liquidity,
    }
}

public(package) fun zero(): MemezBurner {
    MemezBurner {
        fee: bps::new(0),
        target_liquidity: 0,
    }
}

public(package) fun calculate(self: MemezBurner, liquidity: u64): BPS {
    let fee_value = self.fee.value();

    if (fee_value == 0 || liquidity == 0) return bps::new(0);

    if (liquidity >= self.target_liquidity) return bps::new(fee_value);

    let max_bps = bps::max_value!();

    let progress_percentage = u64::mul_div_up(liquidity, max_bps, self.target_liquidity);

    bps::new(u64::mul_div_up(self.fee.value(), progress_percentage, max_bps))
}

// === Test Only ===

#[test_only]
public fun fee(self: MemezBurner): BPS {
    self.fee
}

#[test_only]
public fun target_liquidity(self: MemezBurner): u64 {
    self.target_liquidity
}
