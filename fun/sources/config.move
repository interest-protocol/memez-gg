// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

module memez_fun::memez_config;

use memez_acl::acl::AuthWitness;
use memez_fun::{
    memez_auction_config::{Self, AuctionConfig},
    memez_errors,
    memez_fees::{Self, MemezFees},
    memez_pump_config::{Self, PumpConfig},
    memez_stable_config::{Self, StableConfig}
};
use std::type_name;
use sui::dynamic_field as df;

// === Structs ===

public struct DefaultKey() has copy, drop, store;

public struct FeesKey<phantom T>() has copy, drop, store;

public struct AuctionKey<phantom T>() has copy, drop, store;

public struct PumpKey<phantom T>() has copy, drop, store;

public struct StableKey<phantom T>() has copy, drop, store;

public struct CustomConfigKey<phantom T>() has copy, drop, store;

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

public fun set_auction<Quote, T>(
    self: &mut MemezConfig,
    _: &AuthWitness,
    values: vector<u64>,
    _ctx: &mut TxContext,
) {
    add<AuctionKey<T>, _>(self, memez_auction_config::new<Quote>(values));
}

public fun set_pump<Quote, T>(
    self: &mut MemezConfig,
    _: &AuthWitness,
    values: vector<u64>,
    _ctx: &mut TxContext,
) {
    add<PumpKey<T>, _>(self, memez_pump_config::new<Quote>(values));
}

public fun set_stable<Quote, T>(
    self: &mut MemezConfig,
    _: &AuthWitness,
    values: vector<u64>,
    _ctx: &mut TxContext,
) {
    add<StableKey<T>, _>(self, memez_stable_config::new<Quote>(values));
}

public fun remove<T, Model: drop + store>(
    self: &mut MemezConfig,
    _: &AuthWitness,
    _ctx: &mut TxContext,
) {
    df::remove_if_exists<_, Model>(&mut self.id, type_name::get<T>());
}

public fun allow_custom_config<T>(self: &mut MemezConfig, _: &AuthWitness, _ctx: &mut TxContext) {
    add<CustomConfigKey<T>, _>(self, true);
}

// === Public Package Functions ===

public(package) fun fees<T>(self: &MemezConfig): MemezFees {
    let key = type_name::get<FeesKey<T>>();

    assert!(df::exists_(&self.id, key), memez_errors::model_key_not_supported!());

    *df::borrow(&self.id, key)
}

public(package) fun get_auction<Quote, T>(self: &MemezConfig, total_supply: u64): vector<u64> {
    self.get!<AuctionKey<T>, AuctionConfig, Quote>(total_supply)
}

public(package) fun get_pump<Quote, T>(self: &MemezConfig, total_supply: u64): vector<u64> {
    self.get!<PumpKey<T>, PumpConfig, Quote>(total_supply)
}

public(package) fun get_stable<Quote, T>(self: &MemezConfig, total_supply: u64): vector<u64> {
    self.get!<StableKey<T>, StableConfig, Quote>(total_supply)
}

public(package) fun assert_allows_custom_config<T>(self: &MemezConfig) {
    let key = type_name::get<CustomConfigKey<T>>();

    assert!(df::exists_(&self.id, key), memez_errors::model_key_not_supported!());
}

// === Private Functions ===

macro fun get<$Key, $Model, $Quote>($self: &MemezConfig, $total_supply: u64): _ {
    let self = $self;
    let total_supply = $total_supply;

    assert!(
        df::exists_with_type<_, $Model>(&self.id, type_name::get<$Key>()),
        memez_errors::model_key_not_supported!(),
    );

    df::borrow<_, $Model>(&self.id, type_name::get<$Key>()).get<$Quote>(total_supply)
}

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
