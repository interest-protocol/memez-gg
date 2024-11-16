module memez_fun::memez_fun;
// === Imports === 

use std::{
    string::String,
    type_name::{Self, TypeName},
};

use sui::{
    sui::SUI,
    versioned::Versioned,
    vec_map::{Self, VecMap},
    balance::{Self, Balance},
};

use memez_fun::memez_migration::Migration;

// === Structs === 

public struct MemezFun<phantom Curve, phantom Meme> has key {
    id: UID,
    dev: address,
    state: Versioned, 
    sui_balance: Balance<SUI>,
    meme_balance: Balance<Meme>,
    metadata: VecMap<String, String>,
    migration_witness: TypeName
}

// === Public Package Functions === 

public(package) fun new<Curve, MigrationWitness, Meme>(
    migration: &Migration,
    state: Versioned,
    metadata_names: vector<String>,
    metadata_values: vector<String>,
    ctx: &mut TxContext
): MemezFun<Curve, Meme> {
    let migration_witness = type_name::get<MigrationWitness>(); 

    migration.assert_is_whitelisted(migration_witness);

    MemezFun {
        id: object::new(ctx),
        dev: ctx.sender(),
        state,
        sui_balance: balance::zero(),
        meme_balance: balance::zero(),
        metadata: vec_map::from_keys_values(metadata_names, metadata_values),
        migration_witness,
    }
}

public(package) fun migration_witness<Curve, Meme>(self: &MemezFun<Curve, Meme>): TypeName {
    self.migration_witness
}

public(package) fun dev<Curve, Meme>(self: &MemezFun<Curve, Meme>): address {
    self.dev
} 

public(package) fun state<Curve, Meme>(self: &MemezFun<Curve, Meme>): &Versioned {
    &self.state
}

public(package) fun state_mut<Curve, Meme>(self: &mut MemezFun<Curve, Meme>): &mut Versioned {
    &mut self.state
}

public(package) fun sui_balance<Curve, Meme>(self: &MemezFun<Curve, Meme>): &Balance<SUI> {
    &self.sui_balance
}

public(package) fun meme_balance<Curve, Meme>(self: &MemezFun<Curve, Meme>): &Balance<Meme> {
    &self.meme_balance
} 

public(package) fun sui_balance_mut<Curve, Meme>(self: &mut MemezFun<Curve, Meme>): &mut Balance<SUI> {
    &mut self.sui_balance
}

public(package) fun meme_balance_mut<Curve, Meme>(self: &mut MemezFun<Curve, Meme>): &mut Balance<Meme> {   
    &mut self.meme_balance
}