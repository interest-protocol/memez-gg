module memez_fun::memez_burn; 
// === Imports === 

use interest_math::u64;

// === Constants ===  

const PRECISION: u64 = 1_000_000_000;

// === Public Package Functions === 

public(package) fun calculate_burn_tax(
    start_virtual_liquidity: u64,  
    target_liquidity: u64,
    current_liquidity: u64,
    burn_tax: u64
): u64 {

    if (current_liquidity >= target_liquidity) return 0; 

    if (start_virtual_liquidity >= target_liquidity) return burn_tax; 

    let total_range = target_liquidity - start_virtual_liquidity;  

    let progress = current_liquidity - start_virtual_liquidity;  

    let remaining_percentage = u64::mul_div_down(total_range - progress, PRECISION, total_range);    

    u64::mul_div_up(burn_tax, remaining_percentage, PRECISION)
}