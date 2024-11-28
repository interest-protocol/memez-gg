#[test_only]
module memez_fun::gg;

use sui::{coin, url::new_unsafe_from_bytes};

public struct GG() has drop;

fun init(witness: GG, ctx: &mut TxContext) {
    let (treasury, metadata) = coin::create_currency(
        witness,
        9,
        b"GG",
        b"GG",
        b"GG",
        option::some(new_unsafe_from_bytes(b"memez.gg")),
        ctx,
    );

    transfer::public_transfer(treasury, ctx.sender());
    transfer::public_share_object(metadata);
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(GG(), ctx);
}
