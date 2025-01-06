module memez_otc::events;
// === Imports === 

use std::type_name::{Self, TypeName};

use sui::event::emit; 

// === Structs ===  

public struct New has copy, drop {
    otc: address,
    coin: TypeName,
    owner: address, 
    recipient: address,
    meme_amount: u64,
    desired_sui_amount: u64,
    fee_rate: u64,
    vesting_duration: Option<u64>
}  

public struct Buy has copy, drop {
    otc: address,
    coin: TypeName,
    amount_in: u64,
    amount_out: u64,
    fee: u64,
    vesting_duration: Option<u64>
}

public struct UpdateDeadline has copy, drop {
    otc: address,
    deadline: u64,
    coin: TypeName,
}

public struct Destroy has copy, drop {
    otc: address,
    coin: TypeName,
    owner: address, 
}

// === Package Functions ===

public(package) fun new<CoinType>(
    otc: address,
    owner: address, 
    recipient: address,
    meme_amount: u64,
    desired_sui_amount: u64,
    fee_rate: u64,
    vesting_duration: Option<u64>
) {
    emit(New { 
        otc, 
        coin: type_name::get<CoinType>(), 
        owner, 
        recipient, 
        meme_amount, 
        desired_sui_amount, 
        fee_rate,
        vesting_duration
    });
}

public(package) fun buy<CoinType>(
    otc: address,
    amount_in: u64,
    amount_out: u64,
    fee: u64,
    vesting_duration: Option<u64>
) {
    emit(Buy { 
        otc, 
        coin: type_name::get<CoinType>(), 
        amount_in, 
        amount_out, 
        fee, 
        vesting_duration 
    });
}

public(package) fun update_deadline<CoinType>(
    otc: address,
    deadline: u64
) {
    emit(UpdateDeadline { otc, deadline, coin: type_name::get<CoinType>() });
}

public(package) fun destroy(
    otc: address,
    coin: TypeName,
    owner: address
) {
    emit(Destroy { otc, coin, owner });
}