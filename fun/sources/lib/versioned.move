// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

// Modify the Mysten Labs Versioned to use Prime objects to easily fetch data
// Original code: https://github.com/MystenLabs/sui/blob/main/crates/sui-framework/packages/sui-framework/sources/versioned.move

module memez_fun::memez_versioned;

use sui::dynamic_object_field as dof;

public struct Versioned has key, store {
    id: UID,
    version: u64,
}

public struct VersionChangeCap {
    versioned_id: ID,
    old_version: u64,
}

// === Public Package Functions ===

public(package) fun create<T: key + store>(
    init_version: u64,
    init_value: T,
    ctx: &mut TxContext,
): Versioned {
    let mut self = Versioned {
        id: object::new(ctx),
        version: init_version,
    };
    dof::add(&mut self.id, init_version, init_value);
    self
}

public(package) fun load_value<T: key + store>(self: &Versioned): &T {
    dof::borrow(&self.id, self.version)
}

public(package) fun load_value_mut<T: key + store>(self: &mut Versioned): &mut T {
    dof::borrow_mut(&mut self.id, self.version)
}

public(package) fun remove_value_for_upgrade<T: key + store>(
    self: &mut Versioned,
): (T, VersionChangeCap) {
    (
        dof::remove(&mut self.id, self.version),
        VersionChangeCap {
            versioned_id: object::id(self),
            old_version: self.version,
        },
    )
}

public(package) fun upgrade<T: key + store>(
    self: &mut Versioned,
    new_version: u64,
    new_value: T,
    cap: VersionChangeCap,
) {
    let error = memez_fun::memez_errors::invalid_upgrade!();

    let VersionChangeCap { versioned_id, old_version } = cap;
    assert!(versioned_id == object::id(self), error);
    assert!(old_version < new_version, error);
    dof::add(&mut self.id, new_version, new_value);
    self.version = new_version;
}

public(package) fun destroy<T: key + store>(self: Versioned): T {
    let Versioned { mut id, version } = self;
    let ret = dof::remove(&mut id, version);
    id.delete();
    ret
}

public(package) fun version(self: &Versioned): u64 {
    self.version
}
