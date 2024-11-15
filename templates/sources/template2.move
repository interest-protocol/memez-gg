module memez_templates::meme_2;

// === Imports ===

use sui::{
    coin,
    url::new_unsafe_from_bytes
};

public struct MEME_2 has drop()

const DECIMALS: u8 = 9;
const NAME: vector<u8> = b"Template Coin";
const DESCRIPTION: vector<u8> = b"Template Coin Description";
const URL: vector<u8> = b"url";

fun init(witness: MEME_2, ctx: &mut TxContext) {
    let (treasury, metadata) = coin::create_currency(
        witness, 
        DECIMALS, 
        NAME, 
        NAME, 
        DESCRIPTION, 
        option::some(new_unsafe_from_bytes(URL)), 
        ctx
    );

    transfer::public_transfer(treasury, ctx.sender());
    transfer::public_share_object(metadata);
}