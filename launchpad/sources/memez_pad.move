module memez_pad::memez_pad;

use sui::{
    sui::SUI,
    coin::Coin,
    balance::{Self, Balance}
};

// === Structs ===

public struct Allocation {
    amount: u64,
    vesting_period: u64, 
    
}

public struct MemezSale<phantom CoinType> has key {
    id: UID,
    meme: Balance<CoinType>,
    sui: Balance<SUI>, 
    team_mallocation: u64, 
    liquidity_allocation: u64,

}
