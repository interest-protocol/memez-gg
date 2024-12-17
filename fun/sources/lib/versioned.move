// Modify the Mysten Labs Versioned to have Prime objects to easily fetch data

module memez_fun::memez_versioned;

use memez_fun::memez_errors;
use sui::dynamic_object_field as dfo;

public struct Versioned has key, store {
    id: UID,
    version: u64,
}

public struct VersionChangeCap {
    versioned_id: ID,
    old_version: u64,
}

public fun create<T: key + store>(
    init_version: u64,
    init_value: T,
    ctx: &mut TxContext,
): Versioned {
    let mut self = Versioned {
        id: object::new(ctx),
        version: init_version,
    };
    dfo::add(&mut self.id, init_version, init_value);
    self
}

public fun version(self: &Versioned): u64 {
    self.version
}

public fun load_value<T: key + store>(self: &Versioned): &T {
    dfo::borrow(&self.id, self.version)
}

public fun load_value_mut<T: key + store>(self: &mut Versioned): &mut T {
    dfo::borrow_mut(&mut self.id, self.version)
}

public fun remove_value_for_upgrade<T: key + store>(self: &mut Versioned): (T, VersionChangeCap) {
    (
        dfo::remove(&mut self.id, self.version),
        VersionChangeCap {
            versioned_id: object::id(self),
            old_version: self.version,
        },
    )
}

public fun upgrade<T: key + store>(
    self: &mut Versioned,
    new_version: u64,
    new_value: T,
    cap: VersionChangeCap,
) {
    let error = memez_errors::invalid_upgrade();

    let VersionChangeCap { versioned_id, old_version } = cap;
    assert!(versioned_id == object::id(self), error);
    assert!(old_version < new_version, error);
    dfo::add(&mut self.id, new_version, new_value);
    self.version = new_version;
}

public fun destroy<T: key + store>(self: Versioned): T {
    let Versioned { mut id, version } = self;
    let ret = dfo::remove(&mut id, version);
    id.delete();
    ret
}
