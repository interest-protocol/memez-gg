#[test_only]
module memez_coin_registry::eth;

use sui::coin;

public struct ETH has drop() 

fun init(otw: ETH, ctx: &mut TxContext) {
    let (cap, metadata) = coin::create_currency(
        otw,
        9,
        b"ETH",
        b"Ethereum",
        b"The first smart contract chain",
        option::none(),
        ctx,
    );

    transfer::public_transfer(cap, ctx.sender());
    transfer::public_share_object(metadata);
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ETH(), ctx);
}
