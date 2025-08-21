// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

module memez_fun::memez_metadata;

use std::string::String;
use sui::{coin::CoinMetadata, dynamic_field as df, vec_map::{Self, VecMap}};

// === Structs ===

public struct Key() has copy, drop, store;

public struct MemezMetadata has key, store {
    id: UID,
    decimals: u8,
}

// === Public Functions ===

public fun new<T>(
    coin_metadata: &CoinMetadata<T>,
    metadata_names: vector<String>,
    metadata_values: vector<String>,
    ctx: &mut TxContext,
): MemezMetadata {
    assert!(coin_metadata.get_decimals() == 9, memez_fun::memez_errors::invalid_meme_decimals!());

    let metadata = vec_map::from_keys_values(metadata_names, metadata_values);

    let mut id = object::new(ctx);

    df::add(&mut id, Key(), metadata);

    MemezMetadata {
        id,
        decimals: coin_metadata.get_decimals(),
    }
}

// === Package Functions ===

public(package) fun decimals(self: &MemezMetadata): u8 {
    self.decimals
}

public(package) fun borrow(self: &MemezMetadata): &VecMap<String, String> {
    df::borrow(&self.id, Key())
}

public(package) fun borrow_mut(self: &mut MemezMetadata): &mut VecMap<String, String> {
    df::borrow_mut(&mut self.id, Key())
}

public(package) fun update(self: &mut MemezMetadata, metadata: VecMap<String, String>) {
    df::remove_if_exists<Key, VecMap<String, String>>(&mut self.id, Key());

    df::add(&mut self.id, Key(), metadata);
}

// === Test Functions ===

#[test_only]
public fun new_for_test(ctx: &mut TxContext): MemezMetadata {
    let mut id = object::new(ctx);

    df::add(&mut id, Key(), vec_map::empty<String, String>());

    MemezMetadata {
        id,
        decimals: 9,
    }
}
