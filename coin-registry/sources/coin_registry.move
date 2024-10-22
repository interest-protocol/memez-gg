module memez_coin_registry::memez_coin_registry;
// === Imports === 

use std::type_name::{Self, TypeName};

use sui::{
    coin::CoinMetadata,
    table::{Self, Table},
};

use coin_v2::coin_v2::{TreasuryCapV2, CapWitness};  

// === Structs ===  

public struct CoinInfo has store, copy {
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

public fun add_coin<T>(self: &mut MemezCoinRegistry, cap: &TreasuryCapV2, metadata: &CoinMetadata<T>, witness: CapWitness) {
    let coin_info = CoinInfo {
        treasury_cap_v2: object::id(cap).to_address(),
        metadata: object::id(metadata).to_address(),
        mint_cap: witness.mint_cap_address().destroy_with_default(@0x0),
        burn_cap: witness.burn_cap_address().destroy_with_default(@0x0),
        metadata_cap: witness.metadata_cap_address().destroy_with_default(@0x0)
    };

    self.coins.add(type_name::get<T>(), coin_info);
}

// === Public View Functions ===  

public fun get_coin_info<T>(self: &MemezCoinRegistry): Option<CoinInfo> {
    if (self.coins.contains(type_name::get<T>())) 
        option::some(*self.coins.borrow(type_name::get<T>()))
    else 
        option::none()
}
