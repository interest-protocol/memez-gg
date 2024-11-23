module memez_acl::acl;
// === Imports === 

use std::u64;

use sui::vec_set::{Self, VecSet};

use memez_acl::events;

// === Constants === 

// @dev Each epoch is roughly 1 day
const THREE_EPOCHS: u64 = 3;

// === Errors === 

#[error]
const InvalidEpoch: vector<u8> = b"You can only transfer the super admin after three epochs";

#[error]
const InvalidAdmin: vector<u8> = b"It is not an admin";

#[error]
const InvalidNewSuperAdmin: vector<u8> = b"We do not allow transfers to the zero address or to oneself";

// === Structs === 

public struct AuthWitness() has drop;

public struct SuperAdmin has key {
    id: UID,
    new_admin: address,
    start: u64
}

public struct Admin has key, store {
    id: UID,
}

public struct ACL has key {
    id: UID, 
    admins: VecSet<address>,
}

// === Initializers ===  

fun init(ctx: &mut TxContext) {
    let super_admin = SuperAdmin {
        id: object::new(ctx),
        new_admin: @0x0,
        start: u64::max_value!()
    };

    let acl = ACL {
        id: object::new(ctx), 
        admins: vec_set::empty()
    };

    transfer::share_object(acl);
    transfer::transfer(super_admin, ctx.sender());
}

// === Admin Operations === 

public fun new(acl: &mut ACL, _: &SuperAdmin, ctx: &mut TxContext): Admin {
   let admin = Admin {
        id: object::new(ctx),
   };

   acl.admins.insert(admin.id.to_address());

   events::new_admin(admin.id.to_address());

   admin
}

public fun new_and_transfer(acl: &mut ACL, super_admin: &SuperAdmin, new_admin: address, ctx: &mut TxContext) {
    transfer::public_transfer(new(acl, super_admin, ctx), new_admin);
}

public fun revoke(acl: &mut ACL, _: &SuperAdmin, old_admin: address) {
    acl.admins.remove(&old_admin);

    events::revoke_admin(old_admin);
}

public fun is_admin(acl: &ACL, admin: address): bool {
    acl.admins.contains(&admin)
}

public fun sign_in(acl: &ACL, admin: &Admin): AuthWitness {
    assert!(is_admin(acl, admin.id.to_address()), InvalidAdmin);

    AuthWitness()
}

public fun destroy_admin(acl: &mut ACL, admin: Admin) {
    let Admin { id } = admin; 

    if (acl.admins.contains(&id.to_address()))
        acl.admins.remove(&id.to_address());

    id.delete();
}

// === Transfer Super Admin === 

public fun start_transfer(super_admin: &mut SuperAdmin, new_admin: address, ctx: &mut TxContext) {
    //@dev Destroy it instead for the Sui rebate
    assert!(new_admin != @0x0 && new_admin != ctx.sender(), InvalidNewSuperAdmin);
    
    super_admin.start = ctx.epoch();
    super_admin.new_admin = new_admin;

    events::start_super_admin_transfer(new_admin, super_admin.start);
}

public fun finish_transfer(mut super_admin: SuperAdmin, ctx: &mut TxContext) {
    assert!(ctx.epoch() > super_admin.start + THREE_EPOCHS, InvalidEpoch);

    let new_admin = super_admin.new_admin; 
    super_admin.new_admin = @0x0;
    super_admin.start = u64::max_value!();

    transfer::transfer(super_admin, new_admin);

    events::finish_super_admin_transfer(new_admin);
}

// @dev This is irreversible, the contract does not offer a way to create a new super admin
public fun destroy(super_admin: SuperAdmin) {
    let SuperAdmin { id, .. } = super_admin;
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
public fun admins(acl: &ACL): &VecSet<address> {
    &acl.admins
}

#[test_only]
public fun new_admin(super_admin: &SuperAdmin): address {
    super_admin.new_admin
}

#[test_only]
public fun start(super_admin: &SuperAdmin): u64 {
    super_admin.start
}

#[test_only]
public fun addy(admin: &Admin): address {
    admin.id.to_address()
}