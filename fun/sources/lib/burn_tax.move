module memez_fun::memez_burn_tax;
// === Imports === 

use interest_math::u64;

use memez_fun::memez_utils::pow_9;

// === Structs === 

public struct BurnTax has copy, drop, store {
    tax: u64,
    start_liquidity: u64, 
    target_liquidity: u64, 
}

// === Public Package Functions === 

public(package) fun new(
    tax: u64,
    start_liquidity: u64, 
    target_liquidity: u64, 
): BurnTax {
    BurnTax {
        tax,
        start_liquidity,
        target_liquidity,
    }
}

public(package) fun calculate(
    self: BurnTax,
    liquidity: u64,
): u64 {
    if (liquidity >= self.target_liquidity) return 0; 

    if (self.start_liquidity >= liquidity) return self.tax; 

    let total_range = self.target_liquidity - self.start_liquidity;  

    let progress = liquidity - self.start_liquidity;  

    let pow_9 = pow_9();

    let remaining_percentage = u64::mul_div_down(total_range - progress, pow_9, total_range);    

    u64::mul_div_up(self.tax, remaining_percentage, pow_9)
}

// === Test Only ===  

#[test_only]
public fun tax(self: BurnTax): u64 {
    self.tax
}

#[test_only]
public fun start_liquidity(self: BurnTax): u64 {
    self.start_liquidity
}

#[test_only]
public fun target_liquidity(self: BurnTax): u64 {
    self.target_liquidity
}