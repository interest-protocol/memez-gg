// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

module memez_fun::memez_config;

use memez_acl::acl::AuthWitness;
use memez_fun::{memez_errors, memez_fees::{Self, MemezFees}};
use std::type_name::{Self, TypeName};
use sui::{dynamic_field as df, vec_set::{Self, VecSet}};

// === Structs ===

public struct FeesKey<phantom T>() has copy, drop, store;

public struct QuoteListKey<phantom T>() has copy, drop, store;

public struct MemezConfig has key {
    id: UID,
}

// === Initializer ===

fun init(ctx: &mut TxContext) {
    let config = MemezConfig {
        id: object::new(ctx),
    };

    transfer::share_object(config);
}

// === Public Admin Functions ===

public fun set_fees<T>(
    self: &mut MemezConfig,
    _: &AuthWitness,
    values: vector<vector<u64>>,
    recipients: vector<vector<address>>,
    _ctx: &mut TxContext,
) {
    add<FeesKey<T>, _>(self, memez_fees::new(values, recipients));
}

public fun add_quote_coin<T, Quote>(self: &mut MemezConfig) {
    let quote_coin_name = type_name::get<Quote>();

    let key = QuoteListKey<T>();

    if (df::exists_(&self.id, key)) {
        let quote_list = df::borrow_mut<_, VecSet<TypeName>>(&mut self.id, key);
        quote_list.insert(quote_coin_name);
    } else {
        df::add(&mut self.id, key, vec_set::singleton(quote_coin_name));
    }
}

public fun remove_quote_coin<T, Quote>(self: &mut MemezConfig) {
    let quote_coin_name = type_name::get<Quote>();

    let key = QuoteListKey<T>();

    if (!df::exists_(&self.id, key)) return;

    let quote_list = df::borrow_mut<_, VecSet<TypeName>>(&mut self.id, key);

    quote_list.remove(&quote_coin_name);
}

// === Public Package Functions ===

public(package) fun fees<T>(self: &MemezConfig): MemezFees {
    let key = type_name::get<FeesKey<T>>();

    assert!(df::exists_(&self.id, key), memez_errors::model_key_not_supported!());

    *df::borrow(&self.id, key)
}

public(package) fun assert_quote_coin<T, Quote>(self: &MemezConfig) {
    let key = QuoteListKey<T>();

    assert!(df::exists_(&self.id, key), memez_errors::model_key_not_supported!());

    let quote_list = df::borrow<_, VecSet<TypeName>>(&self.id, key);

    assert!(
        quote_list.contains(&type_name::get<Quote>()),
        memez_errors::quote_coin_not_supported!(),
    );
}

// === Private Functions ===

fun add<ModelKey, Model: drop + store>(self: &mut MemezConfig, model: Model) {
    let key = type_name::get<ModelKey>();

    df::remove_if_exists<_, Model>(&mut self.id, key);

    df::add(&mut self.id, key, model);
}

// === Tests Only Functions ===

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}

#[test_only]
public fun exists_for_testing<T>(self: &MemezConfig): bool {
    df::exists_(&self.id, type_name::get<T>())
}
