module memez_gg::acl;
// === Imports === 

use sui::{
    event::emit,
    vec_set::{Self, VecSet}
};

// === Constants === 

// @dev Each epoch is roughly 1 day
const THREE_EPOCHS: u64 = 3;

// @dev Sentinel value for SuperAdmin.start
const MAX_U64: u64 = 0xFFFFFFFFFFFFFFFF;

// === Errors === 

#[error]
const InvalidEpoch: vector<u8> = b"You can only transfer the super admin after three epochs";

#[error]
const InvalidAdmin: vector<u8> = b"It is not an admin";

#[error]
const InvalidNewAdmin: vector<u8> = b"We do not allow transfers to the zero address or to oneself";

// === Structs === 

public struct AuthWitness has drop {} 

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

// === Events === 

public struct StartSuperAdminTransfer has copy, store, drop {
    new_admin: address,
    start: u64
}

public struct FinishSuperAdminTransfer has copy, store, drop {
    new_admin: address,
}

public struct NewAdmin has copy, store, drop {
    admin: address,
}

public struct RevokeAdmin has copy, store, drop {
    admin: address,
}

// === Initializers ===  

fun init(ctx: &mut TxContext) {
    let super_admin = SuperAdmin {
        id: object::new(ctx),
        new_admin: @0x0,
        start: MAX_U64
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

   emit(NewAdmin {
        admin: admin.id.to_address()
   });

   admin
}

public fun new_and_transfer(acl: &mut ACL, super_admin: &SuperAdmin, new_admin: address, ctx: &mut TxContext) {
    transfer::public_transfer(new(acl, super_admin, ctx), new_admin);
}

public fun revoke(acl: &mut ACL, _: &SuperAdmin, old_admin: address) {
    acl.admins.remove(&old_admin);

    emit(RevokeAdmin {
        admin: old_admin
    });
}

public fun is_admin(acl: &ACL, admin: address): bool {
    acl.admins.contains(&admin)
}

public fun sign_in(acl: &ACL, admin: &Admin): AuthWitness {
    assert!(is_admin(acl, admin.id.to_address()), InvalidAdmin);

    AuthWitness {}
}

public use fun destroy_admin as Admin.destroy;
public fun destroy_admin(admin: Admin) {
    let Admin { id } = admin;
    id.delete();
}

// === Transfer Super Admin === 

public use fun start_super_admin_transfer as SuperAdmin.start_transfer;
public fun start_super_admin_transfer(super_admin: &mut SuperAdmin, new_admin: address, ctx: &mut TxContext) {
    super_admin.start = ctx.epoch();
    super_admin.new_admin = new_admin;

    //@dev Destroy it instead for the Sui rebate
    assert!(new_admin != @0x0 && new_admin != ctx.sender(), InvalidNewAdmin);

    emit(StartSuperAdminTransfer {
        new_admin,
        start: super_admin.start
    });
}

public use fun finish_super_admin_transfer as SuperAdmin.finish_transfer;
public fun finish_super_admin_transfer(mut super_admin: SuperAdmin, ctx: &mut TxContext) {
    assert!(ctx.epoch() > super_admin.start + THREE_EPOCHS, InvalidEpoch);

    let new_admin = super_admin.new_admin; 
    super_admin.new_admin = @0x0;
    super_admin.start = MAX_U64;

    transfer::transfer(super_admin, new_admin);

    emit(FinishSuperAdminTransfer {
        new_admin
    });
}

public use fun destroy_super_admin as SuperAdmin.destroy;
// @dev This is irreversible, the contract does not offer a way to create a new super admin
public fun destroy_super_admin(super_admin: SuperAdmin) {
    let SuperAdmin { id, .. } = super_admin;
    id.delete();
}

// === Test Functions === 

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}