module memez_acl::events;
// === Imports === 

use sui::event::emit; 

// === Structs === 

public struct StartSuperAdminTransfer has copy, store, drop {
    new_admin: address,
    start: u64
}

public struct FinishSuperAdminTransfer(address) has copy, store, drop;

public struct NewAdmin(address) has copy, store, drop;

public struct RevokeAdmin(address) has copy, store, drop;

// === Package Functions ===

public(package) fun start_super_admin_transfer(
    new_admin: address,
    start: u64,
) {
    emit(StartSuperAdminTransfer {
        new_admin,
        start,
    }); 
}

public(package) fun finish_super_admin_transfer(
    new_admin: address,
) {
    emit(FinishSuperAdminTransfer(new_admin));
}

public(package) fun new_admin(
    admin: address,
) {
    emit(NewAdmin(admin));
}

public(package) fun revoke_admin(
    admin: address,
) {
    emit(RevokeAdmin(admin));
}