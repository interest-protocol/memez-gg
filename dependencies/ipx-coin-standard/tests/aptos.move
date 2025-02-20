#[test_only]
module ipx_coin_standard::aptos;

use sui::coin;

public struct APTOS has drop ()

fun init(otw: APTOS, ctx: &mut TxContext) {
    let (cap, metadata) = coin::create_currency(
        otw,
        9,
        b"APT",
        b"Aptos",
        b"The second best move chain",
        option::none(),
        ctx,
    );

    transfer::public_transfer(cap, ctx.sender());
    transfer::public_share_object(metadata);
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(APTOS(), ctx);
}
