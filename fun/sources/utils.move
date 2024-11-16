module memez_fun::memez_utils;
// === Imports === 

use sui::coin::Coin;

// === Constants === 

const DEAD_ADDRESS: address = @0x0;

// === Errors === 

#[error] 
const ESlippage: vector<u8> = b"Slippage";

// === Public Package Functions === 

public(package) fun destroy_or_burn<Meme>(coin: Coin<Meme>) {
    if (coin.value() == 0)
        coin.destroy_zero()
    else 
        transfer::public_transfer(coin, DEAD_ADDRESS);
}

public(package) fun assert_slippage(amount: u64, minimum_expected: u64) {
    assert!(amount >= minimum_expected, ESlippage);
}