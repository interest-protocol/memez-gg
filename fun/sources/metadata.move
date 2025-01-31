// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

module memez_fun::memez_metadata;

use memez_fun::memez_errors;
use std::{ascii::String as ASCIIString, string::String as UTF8String};
use sui::{coin::CoinMetadata, dynamic_field as df, vec_map::{Self, VecMap}};

// === Structs ===

public struct Key() has copy, drop, store;

public struct MemezMetadata has key, store {
    id: UID,
    decimals: u8,
    name: UTF8String,
    symbol: ASCIIString,
}

// === Public Functions ===

public fun new<T>(
    coin_metadata: &CoinMetadata<T>,
    metadata_names: vector<UTF8String>,
    metadata_values: vector<UTF8String>,
    ctx: &mut TxContext,
): MemezMetadata {
    assert!(coin_metadata.get_decimals() == 9, memez_errors::invalid_meme_decimals!());

    let metadata = vec_map::from_keys_values(metadata_names, metadata_values);

    let mut id = object::new(ctx);

    df::add(&mut id, Key(), metadata);

    MemezMetadata {
        id,
        decimals: coin_metadata.get_decimals(),
        name: coin_metadata.get_name(),
        symbol: coin_metadata.get_symbol(),
    }
}

// === Package Functions ===

public(package) fun name(self: &MemezMetadata): UTF8String {
    self.name
}

public(package) fun symbol(self: &MemezMetadata): ASCIIString {
    self.symbol
}

public(package) fun decimals(self: &MemezMetadata): u8 {
    self.decimals
}

public(package) fun borrow(self: &MemezMetadata): &VecMap<UTF8String, UTF8String> {
    df::borrow(&self.id, Key())
}

public(package) fun borrow_mut(self: &mut MemezMetadata): &mut VecMap<UTF8String, UTF8String> {
    df::borrow_mut(&mut self.id, Key())
}

// === Test Functions ===

#[test_only]
public fun new_for_test(ctx: &mut TxContext): MemezMetadata {
    let mut id = object::new(ctx);

    df::add(&mut id, Key(), vec_map::empty<UTF8String, UTF8String>());

    MemezMetadata {
        id,
        decimals: 9,
        name: b"Memez".to_string(),
        symbol: b"MEMEZ".to_ascii_string(),
    }
}
