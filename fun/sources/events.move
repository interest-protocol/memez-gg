module memez_fun::memez_events;
// === Imports === 

use std::type_name::{Self, TypeName};

use memez_fun::memez_events_wrapper::emit_event;

// === Events ===  

public struct New has copy, drop {
    memez_fun: address, 
    meme: TypeName, 
    curve: TypeName,
    migration_witness: TypeName,
}

public struct Pump has copy, drop {
    memez_fun: address, 
    meme: TypeName, 
    sui_amount_in: u64,
    meme_amount_out: u64, 
}

public struct Dump has copy, drop {
    memez_fun: address, 
    meme: TypeName, 
    sui_amount_out: u64,
    meme_amount_in: u64, 
    meme_burn_amount: u64,
} 

public struct CanMigrate has copy, drop {
    memez_fun: address, 
    migration_witness: TypeName,
}

public struct Migrated has copy, drop {
    memez_fun: address, 
    migration_witness: TypeName,
    sui_amount: u64,
    meme_amount: u64,
}   

// === Public Package Functions ===  

public(package) fun new<Curve, Meme>(memez_fun: address, migration_witness: TypeName) {
    emit_event(New { memez_fun, meme: type_name::get<Meme>(), curve: type_name::get<Curve>(),   migration_witness });
}

public(package) fun pump<Meme>(memez_fun: address, sui_amount_in: u64, meme_amount_out: u64) {
    emit_event(Pump { memez_fun, meme: type_name::get<Meme>(), sui_amount_in, meme_amount_out });
}

public(package) fun dump<Meme>(memez_fun: address, sui_amount_out: u64, meme_amount_in: u64, meme_burn_amount: u64) {   
    emit_event(Dump { memez_fun, meme: type_name::get<Meme>(), sui_amount_out, meme_amount_in, meme_burn_amount });
}

public(package) fun can_migrate(memez_fun: address, migration_witness: TypeName) {
    emit_event(CanMigrate { memez_fun, migration_witness });
}

public(package) fun migrated(memez_fun: address, migration_witness: TypeName, sui_amount: u64, meme_amount: u64) {
    emit_event(Migrated { memez_fun, migration_witness, sui_amount, meme_amount });
}