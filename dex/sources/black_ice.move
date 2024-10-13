module memez_dex::black_ice;

use sui::dynamic_object_field as dof;

public struct BlackIceKey() has store, copy, drop;

// @dev Bonus points if you know where this is from. 
public struct BlackIce<phantom T> has key {
    id: UID,
}

// === Public Package Functions ===

public(package) fun freeze_it<T: key + store>(data: T, ctx: &mut TxContext) {
    let mut black_ice = BlackIce<T> {
        id: object::new(ctx),
    };

    dof::add(&mut black_ice.id, BlackIceKey(), data);

    transfer::freeze_object(black_ice);
}