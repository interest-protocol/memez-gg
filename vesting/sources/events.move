module memez_vesting::memez_vesting_events;

use std::{ascii::String, type_name};
use sui::event::emit;

// === Structs ===

public struct Event<T: copy + drop>(T) has copy, drop;

public struct New has copy, drop {
    memez_vesting: address,
    owner: address,
    amount: u64,
    start: u64,
    duration: u64,
    coinType: String,
}

public struct Claimed has copy, drop {
    memez_vesting: address,
    amount: u64,
    coinType: String,
}

public struct Destroyed has copy, drop {
    memez_vesting: address,
    coinType: String,
}

// === Public Package Functions ===

public(package) fun new<T>(
    memez_vesting: address,
    owner: address,
    amount: u64,
    start: u64,
    duration: u64,
) {
    emit(
        Event(New {
            memez_vesting,
            owner,
            amount,
            start,
            duration,
            coinType: type_name::get<T>().into_string(),
        }),
    );
}

public(package) fun claimed<T>(memez_vesting: address, amount: u64) {
    emit(
        Event(Claimed {
            memez_vesting,
            amount,
            coinType: type_name::get<T>().into_string(),
        }),
    );
}

public(package) fun destroyed<T>(memez_vesting: address) {
    emit(Event(Destroyed { memez_vesting, coinType: type_name::get<T>().into_string() }));
}

// === Test Functions ===

#[test_only]
public fun new_event<T>(
    memez_vesting: address,
    owner: address,
    amount: u64,
    start: u64,
    duration: u64,
): Event<New> {
    Event(New {
        memez_vesting,
        owner,
        amount,
        start,
        duration,
        coinType: type_name::get<T>().into_string(),
    })
}

#[test_only]
public fun claimed_event<T>(memez_vesting: address, amount: u64): Event<Claimed> {
    Event(Claimed { memez_vesting, amount, coinType: type_name::get<T>().into_string() })
}

#[test_only]
public fun destroyed_event<T>(memez_vesting: address): Event<Destroyed> {
    Event(Destroyed { memez_vesting, coinType: type_name::get<T>().into_string() })
}
