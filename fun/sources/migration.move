module memez_fun::migration;
// === Imports === 

use std::type_name::{Self, TypeName};

use sui::vec_set::{Self, VecSet};

use memez_acl::acl::AuthWitness;

// === Errors ===

#[error]
const InvalidWitness: vector<u8> = b"This witness is not whitelisted";

// === Structs === 

public struct Migration has key {
    id: UID, 
    whitelisted: VecSet<TypeName>, 
}

// === Initializer === 

fun init(ctx: &mut TxContext) {
    let migration = Migration {
        id: object::new(ctx),
        whitelisted: vec_set::empty(),
    };

    transfer::share_object(migration);
}

// === Public Package Functions === 

public(package) fun is_whitelisted(self: &Migration, witness: TypeName): bool {
    self.whitelisted.contains(&witness)
}

public(package) fun assert_is_whitelisted(self: &Migration, witness: TypeName) {
    assert!(self.is_whitelisted(witness), InvalidWitness);
}

// === Admin Functions === 

public fun add<Witness: drop>(self: &mut Migration, _: &AuthWitness) {
    self.whitelisted.insert(type_name::get<Witness>());
}

public fun remove<Witness: drop>(self: &mut Migration, _: &AuthWitness) {
    self.whitelisted.remove(&type_name::get<Witness>());
}