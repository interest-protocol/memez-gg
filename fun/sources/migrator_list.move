module memez_fun::memez_migrator_list;

use memez_acl::acl::AuthWitness;
use std::type_name::{Self, TypeName};
use sui::vec_set::{Self, VecSet};

// === Errors ===

#[error]
const EInvalidWitness: vector<u8> = b"This witness is not whitelisted";

// === Structs ===

public struct MemezMigratorList has key {
    id: UID,
    whitelisted: VecSet<TypeName>,
}

// === Initializer ===

fun init(ctx: &mut TxContext) {
    let migration = MemezMigratorList {
        id: object::new(ctx),
        whitelisted: vec_set::empty(),
    };

    transfer::share_object(migration);
}

// === Public Package Functions ===

public(package) fun assert_is_whitelisted(self: &MemezMigratorList, witness: TypeName) {
    assert!(self.whitelisted.contains(&witness), EInvalidWitness);
}

// === Admin Functions ===

public fun add<Witness: drop>(self: &mut MemezMigratorList, _: &AuthWitness) {
    self.whitelisted.insert(type_name::get<Witness>());
}

public fun remove<Witness: drop>(self: &mut MemezMigratorList, _: &AuthWitness) {
    self.whitelisted.remove(&type_name::get<Witness>());
}

// === Test Only Functions ===

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}

#[test_only]
public fun whitelisted(self: &MemezMigratorList): &VecSet<TypeName> {
    &self.whitelisted
}
