#[allow(implicit_const_copy)]
module memez_templates::fake_sui;

use sui::{
    coin,
    url::new_unsafe_from_bytes
};

public struct FAKE_SUI has drop()

const DECIMALS: u8 = 9;
const METADATA: vector<vector<u8>> = vector[b"FAKE_SUI", b"Fake SUI", b"Just a fake sui coin", b"https://memez.gg"];

fun init(witness: FAKE_SUI, ctx: &mut TxContext) {
    let (mut treasury, metadata) = coin::create_currency(
        witness, 
        DECIMALS, 
        METADATA[0], 
        METADATA[1], 
        METADATA[2], 
        option::some(new_unsafe_from_bytes(METADATA[3])), 
        ctx
    );

    treasury.mint_and_transfer(10 * 1_000_000_000 * 1_000_000_000, ctx.sender(), ctx);

    transfer::public_transfer(treasury, ctx.sender());
    transfer::public_share_object(metadata);
}