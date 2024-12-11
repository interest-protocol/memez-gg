module memez_acl::acl;

use memez_acl::events;
use std::u64;
use sui::vec_set::{Self, VecSet};

// === Imports ===

// === Constants ===

// @dev Each epoch is roughly 1 day
const THREE_EPOCHS: u64 = 3;

// === Errors ===

#[error]
const InvalidEpoch: vector<u8> = b"You can only transfer the super admin after three epochs";

#[error]
const InvalidAdmin: vector<u8> = b"It is not an admin";

#[error]
const InvalidNewSuperAdmin: vector<u8> =
    b"We do not allow transfers to the zero address or to oneself";

// === Structs ===

public struct AuthWitness() has drop;

public struct MemezSuperAdmin has key {
    id: UID,
    new_admin: address,
    start: u64,
}

public struct MemezAdmin has key, store {
    id: UID,
}

public struct MemezACL has key {
    id: UID,
    admins: VecSet<address>,
}

// === Initializers ===

fun init(ctx: &mut TxContext) {
    let super_admin = MemezSuperAdmin {
        id: object::new(ctx),
        new_admin: @0x0,
        start: u64::max_value!(),
    };

    let acl = MemezACL {
        id: object::new(ctx),
        admins: vec_set::empty(),
    };

    transfer::share_object(acl);
    transfer::transfer(super_admin, ctx.sender());
}

// === Admin Operations ===

public fun new(acl: &mut MemezACL, _: &MemezSuperAdmin, ctx: &mut TxContext): MemezAdmin {
    let admin = MemezAdmin {
        id: object::new(ctx),
    };

    acl.admins.insert(admin.id.to_address());

    events::new_admin(admin.id.to_address());

    admin
}

public fun new_and_transfer(
    acl: &mut MemezACL,
    super_admin: &MemezSuperAdmin,
    new_admin: address,
    ctx: &mut TxContext,
) {
    transfer::public_transfer(new(acl, super_admin, ctx), new_admin);
}

public fun revoke(acl: &mut MemezACL, _: &MemezSuperAdmin, old_admin: address) {
    acl.admins.remove(&old_admin);

    events::revoke_admin(old_admin);
}

public fun is_admin(acl: &MemezACL, admin: address): bool {
    acl.admins.contains(&admin)
}

public fun sign_in(acl: &MemezACL, admin: &MemezAdmin): AuthWitness {
    assert!(is_admin(acl, admin.id.to_address()), InvalidAdmin);

    AuthWitness()
}

public fun destroy_admin(acl: &mut MemezACL, admin: MemezAdmin) {
    let MemezAdmin { id } = admin;

    if (acl.admins.contains(&id.to_address())) acl.admins.remove(&id.to_address());

    id.delete();
}

// === Transfer Super Admin ===

public fun start_transfer(
    super_admin: &mut MemezSuperAdmin,
    new_admin: address,
    ctx: &mut TxContext,
) {
    //@dev Destroy it instead for the Sui rebate
    assert!(new_admin != @0x0 && new_admin != ctx.sender(), InvalidNewSuperAdmin);

    super_admin.start = ctx.epoch();
    super_admin.new_admin = new_admin;

    events::start_super_admin_transfer(new_admin, super_admin.start);
}

public fun finish_transfer(mut super_admin: MemezSuperAdmin, ctx: &mut TxContext) {
    assert!(ctx.epoch() > super_admin.start + THREE_EPOCHS, InvalidEpoch);

    let new_admin = super_admin.new_admin;
    super_admin.new_admin = @0x0;
    super_admin.start = u64::max_value!();

    transfer::transfer(super_admin, new_admin);

    events::finish_super_admin_transfer(new_admin);
}

// @dev This is irreversible, the contract does not offer a way to create a new super admin
public fun destroy(super_admin: MemezSuperAdmin) {
    let MemezSuperAdmin { id, .. } = super_admin;
    id.delete();
}

// === Test Functions ===

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}

#[test_only]
public fun sign_in_for_testing(): AuthWitness {
    AuthWitness()
}

#[test_only]
public fun admins(acl: &MemezACL): &VecSet<address> {
    &acl.admins
}

#[test_only]
public fun new_admin(super_admin: &MemezSuperAdmin): address {
    super_admin.new_admin
}

#[test_only]
public fun start(super_admin: &MemezSuperAdmin): u64 {
    super_admin.start
}

#[test_only]
public fun addy(admin: &MemezAdmin): address {
    admin.id.to_address()
}
