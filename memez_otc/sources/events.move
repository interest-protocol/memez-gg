module memez_otc::events;
// === Imports === 

use std::type_name::{Self, TypeName};

use sui::event::emit; 

// === OTC Events ===  

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

// === Admin Events === 

public struct StartSuperAdminTransfer has copy, drop {
    new_admin: address,
    start: u64
}

public struct FinishSuperAdminTransfer(address) has copy, drop;

public struct NewAdmin(address) has copy, drop;

public struct RevokeAdmin(address) has copy, drop;

// === Package Functions ===

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

public(package) fun new_otc<CoinType>(
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

public(package) fun otc_buy<CoinType>(
    otc: address,
    amount_in: u64,
    amount_out: u64,
    vesting_duration: Option<u64>
) {
    emit(OTCBuy { otc, coin: type_name::get<CoinType>(), amount_in, amount_out, vesting_duration });
}