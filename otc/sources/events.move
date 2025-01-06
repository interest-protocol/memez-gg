module memez_otc::events;

use std::type_name::{Self, TypeName};
use sui::event::emit;

// === Structs ===

public struct New has copy, drop {
    otc: address,
    meme: TypeName,
    owner: address,
    recipient: address,
    meme_amount: u64,
    desired_sui_amount: u64,
    fee: u64,
    meme_scalar: u64,
    vesting_duration: Option<u64>,
    deadline: Option<u64>,
}

public struct Buy has copy, drop {
    otc: address,
    meme: TypeName,
    amount_in: u64,
    amount_out: u64,
    fee: u64,
    vesting_duration: Option<u64>,
}

public struct UpdateDeadline has copy, drop {
    otc: address,
    deadline: u64,
    meme: TypeName,
}

public struct Destroy has copy, drop {
    otc: address,
    meme: TypeName,
    owner: address,
}

// === Package Functions ===

public(package) fun new<Meme>(
    otc: address,
    owner: address,
    recipient: address,
    meme_amount: u64,
    desired_sui_amount: u64,
    fee: u64,
    meme_scalar: u64,
    vesting_duration: Option<u64>,
    deadline: Option<u64>,
) {
    emit(New {
        otc,
        meme: type_name::get<Meme>(),
        owner,
        recipient,
        meme_amount,
        desired_sui_amount,
        fee,
        meme_scalar,
        vesting_duration,
        deadline,
    });
}

public(package) fun buy<Meme>(
    otc: address,
    amount_in: u64,
    amount_out: u64,
    fee: u64,
    vesting_duration: Option<u64>,
) {
    emit(Buy {
        otc,
        meme: type_name::get<Meme>(),
        amount_in,
        amount_out,
        fee,
        vesting_duration,
    });
}

public(package) fun update_deadline<Meme>(otc: address, deadline: u64) {
    emit(UpdateDeadline { otc, deadline, meme: type_name::get<Meme>() });
}

public(package) fun destroy(otc: address, meme: TypeName, owner: address) {
    emit(Destroy { otc, meme, owner });
}
