// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

module memez_fun::memez_config;

use interest_access_control::access_control::AdminWitness;
use memez::memez::MEMEZ;
use memez_fun::{memez_errors, memez_fees::{Self, MemezFees}};
use std::type_name::{Self, TypeName};
use sui::{dynamic_field as df, vec_set::{Self, VecSet}};

// === Structs ===

public struct FeesKey<phantom T>() has copy, drop, store;

public struct QuoteListKey<phantom T>() has copy, drop, store;

public struct MigratorWitnessKey<phantom T>() has copy, drop, store;

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

public fun set_fees<ConfigWitness>(
    self: &mut MemezConfig,
    _: &AdminWitness<MEMEZ>,
    values: vector<vector<u64>>,
    recipients: vector<vector<address>>,
    _ctx: &mut TxContext,
) {
    add<FeesKey<ConfigWitness>, _>(self, memez_fees::new(values, recipients));
}

public fun remove<ConfigWitness, Model: drop + store>(
    self: &mut MemezConfig,
    _: &AdminWitness<MEMEZ>,
    _ctx: &mut TxContext,
) {
    df::remove_if_exists<_, Model>(&mut self.id, type_name::get<ConfigWitness>());
}

public fun add_quote_coin<ConfigWitness, Quote>(
    self: &mut MemezConfig,
    _: &AdminWitness<MEMEZ>,
    _: &mut TxContext,
) {
    self.add_to_set<Quote, _>(QuoteListKey<ConfigWitness>());
}

public fun remove_quote_coin<ConfigWitness, Quote>(
    self: &mut MemezConfig,
    _: &AdminWitness<MEMEZ>,
    _: &mut TxContext,
) {
    self.remove_from_set<Quote, _>(QuoteListKey<ConfigWitness>());
}

public fun add_migrator_witness<ConfigWitness, MigratorWitness>(
    self: &mut MemezConfig,
    _: &AdminWitness<MEMEZ>,
    _: &mut TxContext,
) {
    self.add_to_set<MigratorWitness, _>(MigratorWitnessKey<ConfigWitness>());
}

public fun remove_migrator_witness<ConfigWitness, MigratorWitness>(
    self: &mut MemezConfig,
    _: &AdminWitness<MEMEZ>,
    _: &mut TxContext,
) {
    self.remove_from_set<MigratorWitness, _>(MigratorWitnessKey<ConfigWitness>());
}

// === Public Package Functions ===

public(package) fun fees<ConfigWitness>(self: &MemezConfig): MemezFees {
    let key = type_name::get<FeesKey<ConfigWitness>>();

    assert!(df::exists_(&self.id, key), memez_errors::model_key_not_supported!());

    *df::borrow(&self.id, key)
}

public(package) fun assert_quote_coin<ConfigWitness, Quote>(self: &MemezConfig) {
    let key = QuoteListKey<ConfigWitness>();

    assert!(df::exists_(&self.id, key), memez_errors::model_key_not_supported!());

    let quote_list = df::borrow<_, VecSet<TypeName>>(&self.id, key);

    assert!(
        quote_list.contains(&type_name::get<Quote>()),
        memez_errors::quote_coin_not_supported!(),
    );
}

public(package) fun assert_migrator_witness<ConfigWitness, MigratorWitness>(self: &MemezConfig) {
    let key = MigratorWitnessKey<ConfigWitness>();

    assert!(df::exists_(&self.id, key), memez_errors::model_key_not_supported!());

    let migrator_witness_list = df::borrow<_, VecSet<TypeName>>(&self.id, key);

    assert!(
        migrator_witness_list.contains(&type_name::get<MigratorWitness>()),
        memez_errors::migrator_witness_not_supported!(),
    );
}

// === Private Functions ===

fun add<ModelKey, Model: drop + store>(self: &mut MemezConfig, model: Model) {
    let key = type_name::get<ModelKey>();

    df::remove_if_exists<_, Model>(&mut self.id, key);

    df::add(&mut self.id, key, model);
}

fun add_to_set<Witness, Key: copy + drop + store>(self: &mut MemezConfig, key: Key) {
    let witness_name = type_name::get<Witness>();

    if (df::exists_(&self.id, key)) {
        let quote_list = df::borrow_mut<_, VecSet<TypeName>>(&mut self.id, key);
        quote_list.insert(witness_name);
    } else {
        df::add(&mut self.id, key, vec_set::singleton(witness_name));
    }
}

fun remove_from_set<Witness, Key: copy + drop + store>(self: &mut MemezConfig, key: Key) {
    let witness_name = type_name::get<Witness>();

    if (!df::exists_(&self.id, key)) return;

    let quote_list = df::borrow_mut<_, VecSet<TypeName>>(&mut self.id, key);

    if (quote_list.contains(&witness_name)) {
        quote_list.remove(&witness_name);
    }
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
