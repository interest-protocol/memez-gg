module memez_gg::events;
// === Imports === 

use std::type_name::{Self, TypeName};

use sui::{
    sui::SUI,
    event::emit
}; 

// === Structs === 

public struct NewPool has copy, drop, store {
    memez_pool: address,
    af_pool: address,
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

public struct StartSuperAdminTransfer has copy, store, drop {
    new_admin: address,
    start: u64
}

public struct FinishSuperAdminTransfer(address) has copy, store, drop;

public struct NewAdmin(address) has copy, store, drop;

public struct RevokeAdmin(address) has copy, store, drop;

// === Package Functions ===

public(package) fun new_pool<Meme, LpCoin>(
    memez_pool: address, 
    af_pool: address
) { 
    emit(NewPool {
        memez_pool,
        af_pool,
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

public(package) fun start_super_admin_transfer(
    new_admin: address,
    start: u64,
) {
    emit(StartSuperAdminTransfer {
        new_admin,
        start,
    }); 
}

public(package) fun finish_super_admin_transfer(
    new_admin: address,
) {
    emit(FinishSuperAdminTransfer(new_admin));
}

public(package) fun new_admin(
    admin: address,
) {
    emit(NewAdmin(admin));
}

public(package) fun revoke_admin(
    admin: address,
) {
    emit(RevokeAdmin(admin));
}