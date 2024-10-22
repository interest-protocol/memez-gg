module memez_coin_registry::memez_coin_registry;
// === Imports === 

use std::type_name::{Self, TypeName};

use sui::{
    coin::CoinMetadata,
    table::{Self, Table},
};

use coin_v2::coin_v2::{TreasuryCapV2, CapWitness};  

// === Errors ===  

#[error]
const EInvalidCoinType: vector<u8> = b"Coin types do not match";

#[error]
const EInvalidTreasuryCap: vector<u8> = b"Invalid treasury cap";

// === Structs ===  

public struct CoinInfo has store, copy, drop {
    treasury_cap_v2: address,
    metadata: address,
    mint_cap: address,
    burn_cap: address,
    metadata_cap: address
}

public struct MemezCoinRegistry has key {
    id: UID,
    coins: Table<TypeName, CoinInfo>
}

// === Initialization ===  

fun init(ctx: &mut TxContext) {
    let registry = MemezCoinRegistry {
        id: object::new(ctx),
        coins: table::new(ctx)
    };

    transfer::share_object(registry);
}

// === Public Mutative Functions ===  

public fun add<T>(
    self: &mut MemezCoinRegistry, 
    cap: &TreasuryCapV2, 
    metadata: &CoinMetadata<T>, 
    witness: CapWitness
) {
    assert!(type_name::get<T>() == witness.name(), EInvalidCoinType);

    let cap_address = object::id(cap).to_address();

    assert!(cap_address == witness.treasury(), EInvalidTreasuryCap);

    let coin_info = CoinInfo {
        treasury_cap_v2: cap_address,
        metadata: object::id(metadata).to_address(),
        mint_cap: witness.mint_cap_address().destroy_with_default(@0x0),
        burn_cap: witness.burn_cap_address().destroy_with_default(@0x0),
        metadata_cap: witness.metadata_cap_address().destroy_with_default(@0x0)
    };

    self.coins.add(type_name::get<T>(), coin_info);
}

// === Public View Functions ===  

public fun get<T>(self: &MemezCoinRegistry): Option<CoinInfo> {
    if (self.coins.contains(type_name::get<T>())) 
        option::some(*self.coins.borrow(type_name::get<T>()))
    else 
        option::none()
}

// === Test Only Functions ===   

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}

#[test_only]
public fun treasury_cap_v2(coin_info: CoinInfo): address {
    coin_info.treasury_cap_v2
}

#[test_only]
public fun metadata(coin_info: CoinInfo): address {
    coin_info.metadata
}

#[test_only]
public fun mint_cap(coin_info: CoinInfo): address {
    coin_info.mint_cap
}

#[test_only]
public fun burn_cap(coin_info: CoinInfo): address {
    coin_info.burn_cap
}

#[test_only]    
public fun metadata_cap(coin_info: CoinInfo): address {
    coin_info.metadata_cap
}