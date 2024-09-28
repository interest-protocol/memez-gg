module memez_gg::black_ice;

// @dev Bonus points if you know where this is from. 
public struct BlackIce<T: store> has key {
    id: UID,
    data: T,
}

// === Public Package Functions ===

public(package) fun freeze_it<T: store>(data: T, ctx: &mut TxContext) {
    let black_ice = BlackIce<T> {
        id: object::new(ctx),
        data,
    };

    transfer::freeze_object(black_ice);
}