module memez_fun::memez_utils;
// === Imports === 

use sui::coin::Coin;

// === Constants === 

const DEAD_ADDRESS: address = @0x0;

const POW_9: u64 = 1__000_000_000;

// === Errors === 

#[error] 
const ESlippage: vector<u8> = b"Slippage";

#[error]
const EZeroCoin: vector<u8> = b"Coin value must be greater than 0"; 

// === Public Package Functions === 

public(package) fun pow_9(): u64 {
    POW_9
}

public(package) fun assert_coin_has_value<T>(coin: &Coin<T>): u64 {
    let value = coin.value();
    assert!(value > 0, EZeroCoin);
    value
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