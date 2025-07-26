// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

module memez_fun::memez_events;

use memez_fun::memez_events_wrapper::emit_event;
use std::type_name::{Self, TypeName};

// === Events ===

public struct New has copy, drop {
    memez_fun: address,
    public_key: vector<u8>,
    inner_state: address,
    dev: address,
    meme: TypeName,
    quote: TypeName,
    curve: TypeName,
    config_key: TypeName,
    migration_witness: TypeName,
    ipx_meme_coin_treasury: address,
    virtual_liquidity: u64,
    target_quote_liquidity: u64,
    meme_balance: u64,
    meme_total_supply: u64,
}

public struct Pump has copy, drop {
    memez_fun: address,
    inner_state: address,
    meme: TypeName,
    quote: TypeName,
    quote_amount_in: u64,
    meme_amount_out: u64,
    meme_swap_fee: u64,
    quote_swap_fee: u64,
    quote_balance: u64,
    meme_balance: u64,
    quote_virtual_liquidity: u64,
    referrer: Option<address>,
    meme_referrer_fee: u64,
    quote_referrer_fee: u64,
}

public struct Dump has copy, drop {
    memez_fun: address,
    inner_state: address,
    meme: TypeName,
    quote: TypeName,
    quote_amount_out: u64,
    meme_amount_in: u64,
    meme_swap_fee: u64,
    quote_swap_fee: u64,
    meme_burn_amount: u64,
    quote_balance: u64,
    meme_balance: u64,
    quote_virtual_liquidity: u64,
    referrer: Option<address>,
    meme_referrer_fee: u64,
    quote_referrer_fee: u64,
}

public struct CanMigrate has copy, drop {
    memez_fun: address,
    migration_witness: TypeName,
}

public struct Migrated has copy, drop {
    memez_fun: address,
    migration_witness: TypeName,
    quote_amount: u64,
    meme_amount: u64,
    meme: TypeName,
    quote: TypeName,
}

// === Public Package Functions ===

public(package) fun new<Curve, Meme, Quote>(
    memez_fun: address,
    public_key: vector<u8>,
    inner_state: address,
    dev: address,
    config_key: TypeName,
    migration_witness: TypeName,
    ipx_meme_coin_treasury: address,
    virtual_liquidity: u64,
    target_quote_liquidity: u64,
    meme_balance: u64,
    meme_total_supply: u64,
) {
    emit_event(New {
        memez_fun,
        public_key,
        inner_state,
        dev,
        meme: type_name::get<Meme>(),
        quote: type_name::get<Quote>(),
        curve: type_name::get<Curve>(),
        config_key,
        migration_witness,
        ipx_meme_coin_treasury,
        virtual_liquidity,
        target_quote_liquidity,
        meme_balance,
        meme_total_supply,
    });
}

public(package) fun pump<Meme, Quote>(
    memez_fun: address,
    inner_state: address,
    quote_amount_in: u64,
    meme_amount_out: u64,
    meme_swap_fee: u64,
    quote_swap_fee: u64,
    quote_balance: u64,
    meme_balance: u64,
    quote_virtual_liquidity: u64,
    referrer: Option<address>,
    meme_referrer_fee: u64,
    quote_referrer_fee: u64,
) {
    emit_event(Pump {
        memez_fun,
        inner_state,
        meme: type_name::get<Meme>(),
        quote: type_name::get<Quote>(),
        quote_amount_in,
        meme_amount_out,
        meme_swap_fee,
        quote_swap_fee,
        quote_balance,
        meme_balance,
        quote_virtual_liquidity,
        referrer,
        quote_referrer_fee,
        meme_referrer_fee,
    });
}

public(package) fun dump<Meme, Quote>(
    memez_fun: address,
    inner_state: address,
    meme_amount_in: u64,
    quote_amount_out: u64,
    meme_swap_fee: u64,
    quote_swap_fee: u64,
    meme_burn_amount: u64,
    quote_balance: u64,
    meme_balance: u64,
    quote_virtual_liquidity: u64,
    referrer: Option<address>,
    meme_referrer_fee: u64,
    quote_referrer_fee: u64,
) {
    emit_event(Dump {
        memez_fun,
        inner_state,
        meme: type_name::get<Meme>(),
        quote: type_name::get<Quote>(),
        quote_amount_out,
        meme_amount_in,
        meme_swap_fee,
        quote_swap_fee,
        meme_burn_amount,
        quote_balance,
        meme_balance,
        quote_virtual_liquidity,
        referrer,
        quote_referrer_fee,
        meme_referrer_fee,
    });
}

public(package) fun can_migrate(memez_fun: address, migration_witness: TypeName) {
    emit_event(CanMigrate { memez_fun, migration_witness });
}

public(package) fun migrated<Meme, Quote>(
    memez_fun: address,
    migration_witness: TypeName,
    meme_amount: u64,
    quote_amount: u64,
) {
    emit_event(Migrated {
        memez_fun,
        migration_witness,
        meme_amount,
        quote_amount,
        meme: type_name::get<Meme>(),
        quote: type_name::get<Quote>(),
    });
}
