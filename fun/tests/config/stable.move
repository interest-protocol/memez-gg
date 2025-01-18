#[test_only]
module memez_fun::memez_stable_model_tests;

use memez_fun::{memez_errors, memez_stable_config};
use std::{type_name, unit_test::assert_eq};
use sui::test_utils::destroy;

// @dev 50,000,000 = 5%
const LIQUIDITY_PROVISION: u64 = 600;

const MEME_SALE_AMOUNT: u64 = 2_000;

const MAX_TARGET_SUI_LIQUIDITY: u64 = 1_000_000_000;

public struct Quote()

public struct InvalidQuote()

#[test]
fun test_end_to_end() {
    let auction = memez_stable_config::new<Quote>(vector[
        MAX_TARGET_SUI_LIQUIDITY,
        LIQUIDITY_PROVISION,
        MEME_SALE_AMOUNT,
    ]);

    let payload = auction.get<Quote>(100);

    assert_eq!(payload[0], MAX_TARGET_SUI_LIQUIDITY);
    assert_eq!(payload[1], 6);
    assert_eq!(payload[2], 20);
    assert_eq!(auction.quote_type(), type_name::get<Quote>());

    destroy(auction);
}

#[test, expected_failure(abort_code = memez_errors::EInvalidConfig, location = memez_stable_config)]
fun test_new_invalid_config() {
    let auction = memez_stable_config::new<Quote>(vector[MAX_TARGET_SUI_LIQUIDITY, LIQUIDITY_PROVISION]);

    destroy(auction);
}

#[test, expected_failure(abort_code = memez_errors::EInvalidQuoteType, location = memez_stable_config)]
fun test_new_invalid_quote() {
    let auction = memez_stable_config::new<Quote>(vector[
        MAX_TARGET_SUI_LIQUIDITY,
        LIQUIDITY_PROVISION,
        MEME_SALE_AMOUNT,
    ]);
    

    auction.get<InvalidQuote>(100);

    destroy(auction);
}
