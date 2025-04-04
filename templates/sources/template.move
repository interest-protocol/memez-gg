#[allow(implicit_const_copy)]
module memez_templates::meme;

use sui::{
    coin,
    url::new_unsafe_from_bytes
};

public struct MEME has drop()

const DECIMALS: u8 = 9;
const METADATA: vector<vector<u8>> = vector[b"MEME", b"Meme Coin", b"Just a meme coin", b"https://memez.gg"];

fun init(witness: MEME, ctx: &mut TxContext) {
    let (treasury, metadata) = coin::create_currency(
        witness, 
        DECIMALS, 
        METADATA[0], 
        METADATA[1], 
        METADATA[2], 
        option::some(new_unsafe_from_bytes(METADATA[3])), 
        ctx
    );

    transfer::public_transfer(treasury, ctx.sender());
    transfer::public_share_object(metadata);
}