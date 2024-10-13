module memez_otc::otc_events;
// === Imports === 

use std::type_name::{Self, TypeName};

use sui::event::emit; 

// === Structs ===  

public struct NewOTC has copy, drop {
    otc: address,
    coin: TypeName,
    owner: address, 
    recipient: address,
    deposited_amount: u64,
    price: u64,
    fee_rate: u64,
    vesting_duration: Option<u64>
}  

public struct OTCBuy has copy, drop {
    otc: address,
    coin: TypeName,
    amount_in: u64,
    amount_out: u64,
    vesting_duration: Option<u64>
}

// === Package Functions ===

public(package) fun new<CoinType>(
    otc: address,
    owner: address, 
    recipient: address,
    deposited_amount: u64,
    price: u64,
    fee_rate: u64,
    vesting_duration: Option<u64>
) {
    emit(NewOTC { 
        otc, 
        coin: type_name::get<CoinType>(), 
        owner, 
        recipient, 
        deposited_amount, 
        price, 
        fee_rate,
        vesting_duration
    });
}

public(package) fun buy<CoinType>(
    otc: address,
    amount_in: u64,
    amount_out: u64,
    vesting_duration: Option<u64>
) {
    emit(OTCBuy { otc, coin: type_name::get<CoinType>(), amount_in, amount_out, vesting_duration });
}