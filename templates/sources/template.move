#[allow(implicit_const_copy)]
module memez_templates::last_test;

use sui::{
    coin,
    url::new_unsafe_from_bytes
};

public struct LAST_TEST has drop()

const DECIMALS: u8 = 9;
const METADATA: vector<vector<u8>> = vector[b"LAST_TEST", b"Last Test Coin", b"Just a last test coin", b"https://memez.gg"];

fun init(witness: LAST_TEST, ctx: &mut TxContext) {
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