module memez_gg::events;
// === Imports === 

use std::type_name::{Self, TypeName};

use sui::{
    sui::SUI,
    event::emit
}; 

// === Structs === 

public struct NewPool has copy, drop, store {
    pool_id: address,
    vault_id: address,
    vault_cap_id: address,
    sui: TypeName,
    meme: TypeName,
    lp_coin: TypeName,
}

public struct CollectFee has copy, drop, store {
    vault_id: address,
    vault_cap_id: address,
    sui_amount: u64,
    meme_amount: u64,
    sui: TypeName,
    meme: TypeName,
    lp_coin: TypeName,
}

public struct AdminCollectFee has copy, drop, store {
    vault_id: address,
    sui_amount: u64,
    meme_amount: u64,
    sui: TypeName,
    meme: TypeName,
    lp_coin: TypeName,
}

// === Package Functions ===

public(package) fun new_pool<Meme, LpCoin>(
    pool_id: address,
    vault_id: address,
    vault_cap_id: address,
) { 
    emit(NewPool {
        pool_id,
        vault_id,
        vault_cap_id,
        sui: type_name::get<SUI>(),
        meme: type_name::get<Meme>(),
        lp_coin: type_name::get<LpCoin>(),
    });
}

public(package) fun collect_fee<Meme, LpCoin>(
    vault_id: address,
    vault_cap_id: address,
    sui_amount: u64,
    meme_amount: u64,
) {     
    emit(CollectFee {
        vault_id,
        vault_cap_id,
        sui_amount,
        meme_amount,
        sui: type_name::get<SUI>(),
        meme: type_name::get<Meme>(),
        lp_coin: type_name::get<LpCoin>(),
    });
}

public(package) fun admin_collect_fee<Meme, LpCoin>(
    vault_id: address,
    sui_amount: u64,
    meme_amount: u64,
) {
    emit(AdminCollectFee {
        vault_id,
        sui_amount,
        meme_amount,
        sui: type_name::get<SUI>(),
        meme: type_name::get<Meme>(),
        lp_coin: type_name::get<LpCoin>(),
    });
}   