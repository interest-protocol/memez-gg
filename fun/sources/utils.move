module memez_fun::memez_utils;
// === Imports === 

use sui::coin::Coin;

// === Constants === 

const DEAD_ADDRESS: address = @0x0;

// === Public Package Functions === 

public(package) fun destroy_or_burn<Meme>(coin: Coin<Meme>) {
    if (coin.value() == 0)
        coin.destroy_zero()
    else 
        transfer::public_transfer(coin, DEAD_ADDRESS);
}