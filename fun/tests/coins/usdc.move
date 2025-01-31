#[test_only]
module memez_fun::usdc;

use sui::{coin, url::new_unsafe_from_bytes};

public struct USDC() has drop;

fun init(witness: USDC, ctx: &mut TxContext) {
    let (treasury, metadata) = coin::create_currency(
        witness,
        6,
        b"USDC",
        b"USDC",
        b"USDC",
        option::some(new_unsafe_from_bytes(b"memez.gg")),
        ctx,
    );

    transfer::public_transfer(treasury, ctx.sender());
    transfer::public_share_object(metadata);
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(USDC(), ctx);
}
