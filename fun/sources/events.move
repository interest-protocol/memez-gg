// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

module memez_fun::memez_events;

use memez_fun::memez_events_wrapper::emit_event;
use std::type_name::{Self, TypeName};

// === Events ===

public struct New has copy, drop {
    memez_fun: address,
    inner_state: address,
    meme: TypeName,
    curve: TypeName,
    config_key: TypeName,
    migration_witness: TypeName,
    ipx_meme_coin_treasury: address,
    virtual_liquidity: u64,
    target_sui_liquidity: u64,
    meme_balance: u64,
}

public struct Pump has copy, drop {
    memez_fun: address,
    meme: TypeName,
    sui_amount_in: u64,
    meme_amount_out: u64,
    swap_fee: u64,
    sui_balance: u64,
    meme_balance: u64,
    sui_virtual_liquidity: u64,
}

public struct Dump has copy, drop {
    memez_fun: address,
    meme: TypeName,
    sui_amount_out: u64,
    meme_amount_in: u64,
    swap_fee: u64,
    meme_burn_amount: u64,
    sui_balance: u64,
    meme_balance: u64,
    sui_virtual_liquidity: u64,
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

public(package) fun new<Curve, Meme>(
    memez_fun: address,
    inner_state: address,
    config_key: TypeName,
    migration_witness: TypeName,
    ipx_meme_coin_treasury: address,
    virtual_liquidity: u64,
    target_sui_liquidity: u64,
    meme_balance: u64,
) {
    emit_event(New {
        memez_fun,
        inner_state,
        meme: type_name::get<Meme>(),
        curve: type_name::get<Curve>(),
        config_key,
        migration_witness,
        ipx_meme_coin_treasury,
        virtual_liquidity,
        target_sui_liquidity,
        meme_balance,
    });
}

public(package) fun pump<Meme>(
    memez_fun: address,
    sui_amount_in: u64,
    meme_amount_out: u64,
    swap_fee: u64,
    sui_balance: u64,
    meme_balance: u64,
    sui_virtual_liquidity: u64,
) {
    emit_event(Pump {
        memez_fun,
        meme: type_name::get<Meme>(),
        sui_amount_in,
        meme_amount_out,
        swap_fee,
        sui_balance,
        meme_balance,
        sui_virtual_liquidity,
    });
}

public(package) fun dump<Meme>(
    memez_fun: address,
    sui_amount_out: u64,
    meme_amount_in: u64,
    swap_fee: u64,
    meme_burn_amount: u64,
    sui_balance: u64,
    meme_balance: u64,
    sui_virtual_liquidity: u64,
) {
    emit_event(Dump {
        memez_fun,
        meme: type_name::get<Meme>(),
        sui_amount_out,
        meme_amount_in,
        swap_fee,
        meme_burn_amount,
        sui_balance,
        meme_balance,
        sui_virtual_liquidity,
    });
}

public(package) fun can_migrate(memez_fun: address, migration_witness: TypeName) {
    emit_event(CanMigrate { memez_fun, migration_witness });
}

public(package) fun migrated(
    memez_fun: address,
    migration_witness: TypeName,
    sui_amount: u64,
    meme_amount: u64,
) {
    emit_event(Migrated { memez_fun, migration_witness, sui_amount, meme_amount });
}
