// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

module memez_fun::memez_metadata;

use std::string::String;
use sui::{dynamic_field as df, vec_map::{Self, VecMap}};

// === Structs ===

public struct Key() has copy, drop, store;

public struct MemezMetadata has key, store {
    id: UID,
}

// === Public Functions === 

public fun new(
    metadata_names: vector<String>,
    metadata_values: vector<String>,
    ctx: &mut TxContext,
): MemezMetadata {
    let metadata = vec_map::from_keys_values(metadata_names, metadata_values);

    let mut id = object::new(ctx);

    df::add(&mut id, Key(), metadata);

    MemezMetadata {
        id,
    }
}

// === Package Functions ===

public(package) fun borrow(self: &MemezMetadata): &VecMap<String, String> {
    df::borrow(&self.id, Key())
}

public(package) fun borrow_mut(self: &mut MemezMetadata): &mut VecMap<String, String> {
    df::borrow_mut(&mut self.id, Key())
}
