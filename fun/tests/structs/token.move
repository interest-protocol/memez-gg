#[test_only]
module memez_fun::memez_token_cap_tests;

use memez_fun::memez_token_cap;
use std::unit_test::assert_eq;
use sui::{coin::{mint_for_testing, create_treasury_cap_for_testing}, test_utils::destroy};

public struct Meme()

#[test]
fun test_end_to_end() {
    let mut ctx = tx_context::dummy();

    let treasury_cap = create_treasury_cap_for_testing<Meme>(&mut ctx);

    let cap = memez_token_cap::new(&treasury_cap, &mut ctx);

    let value = 1000;

    let meme_token = cap.from_coin(mint_for_testing<Meme>(value, &mut ctx), &mut ctx);

    assert_eq!(meme_token.value(), value);

    let meme_coin = cap.to_coin(meme_token, &mut ctx);

    assert_eq!(meme_coin.burn_for_testing(), value);

    destroy(cap);
    destroy(treasury_cap);
}
