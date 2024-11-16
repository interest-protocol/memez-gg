module memez_fun::memez_utils;
// === Imports === 

use sui::coin::Coin;

use interest_math::u64;

// === Constants === 

const DEAD_ADDRESS: address = @0x0;

const POW_9: u64 = 1__000_000_000;

// === Errors === 

#[error] 
const ESlippage: vector<u8> = b"Slippage";

#[error]
const EZeroCoin: vector<u8> = b"Coin value must be greater than 0"; 

// === Public Package Functions === 

public(package) fun assert_coin_has_value<T>(coin: &Coin<T>): u64 {
    assert!(coin.value() > 0, EZeroCoin);
    coin.value()
}

public(package) fun destroy_or_burn<Meme>(coin: Coin<Meme>) {
    if (coin.value() == 0)
        coin.destroy_zero()
    else 
        transfer::public_transfer(coin, DEAD_ADDRESS);
}

public(package) fun assert_slippage(amount: u64, minimum_expected: u64) {
    assert!(amount >= minimum_expected, ESlippage);
}

public(package) fun get_dynamic_burn_tax(
    start_liquidity: u64, 
    target_liquidity: u64, 
    liquidity: u64,
    burn_tax: u64, 
): u64 {
    if (liquidity >= target_liquidity) return 0; 

    if (start_liquidity >= liquidity) return burn_tax; 

    let total_range = target_liquidity - start_liquidity;  

    let progress = liquidity - start_liquidity;  

    let remaining_percentage = u64::mul_div_down(total_range - progress, POW_9, total_range);    

    u64::mul_div_up(burn_tax, remaining_percentage, POW_9)
}
