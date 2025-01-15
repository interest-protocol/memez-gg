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

public fun set_auction<T>(
    self: &mut MemezConfig,
    _: &AuthWitness,
    values: vector<u64>,
    _ctx: &mut TxContext,
) {
    add<AuctionKey<T>, _>(self, memez_auction_config::new(values));
}

public fun set_pump<T>(
    self: &mut MemezConfig,
    _: &AuthWitness,
    values: vector<u64>,
    _ctx: &mut TxContext,
) {
    add<PumpKey<T>, _>(self, memez_pump_config::new(values));
}

public fun set_stable<T>(
    self: &mut MemezConfig,
    _: &AuthWitness,
    values: vector<u64>,
    _ctx: &mut TxContext,
) {
    add<StableKey<T>, _>(self, memez_stable_config::new(values));
}

public fun remove<T, Model: drop + store>(
    self: &mut MemezConfig,
    _: &AuthWitness,
    _ctx: &mut TxContext,
) {
    df::remove_if_exists<_, Model>(&mut self.id, type_name::get<T>());
}

// === Public Package Functions ===

public(package) fun fees<T>(self: &MemezConfig): MemezFees {
    let key = type_name::get<FeesKey<T>>();

    assert!(df::exists_(&self.id, key), memez_errors::model_key_not_supported!());

    *df::borrow(&self.id, key)
}

public(package) fun get_auction<T>(self: &MemezConfig, total_supply: u64): vector<u64> {
    self.get!<AuctionKey<T>, AuctionConfig>(total_supply)
}

public(package) fun get_pump<T>(self: &MemezConfig, total_supply: u64): vector<u64> {
    self.get!<PumpKey<T>, PumpConfig>(total_supply)
}

public(package) fun get_stable<T>(self: &MemezConfig, total_supply: u64): vector<u64> {
    self.get!<StableKey<T>, StableConfig>(total_supply)
}

// === Private Functions ===

macro fun get<$Key, $Model>($self: &MemezConfig, $total_supply: u64): _ {
    let self = $self;
    let total_supply = $total_supply;

    assert!(
        df::exists_with_type<_, $Model>(&self.id, type_name::get<$Key>()),
        memez_errors::model_key_not_supported!(),
    );

    df::borrow<_, $Model>(&self.id, type_name::get<$Key>()).get(total_supply)
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
