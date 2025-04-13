#[test_only]
module memez_fun::memez_stable_model_tests;

use memez_fun::{memez_errors, memez_stable_config};
use std::unit_test::assert_eq;

// @dev 50,000,000 = 5%
const LIQUIDITY_PROVISION: u64 = 600;

const MEME_SALE_AMOUNT: u64 = 2_000;

const MAX_TARGET_SUI_LIQUIDITY: u64 = 1_000_000_000;

public struct Quote()

public struct InvalidQuote()

#[test]
fun test_end_to_end() {
    let stable = memez_stable_config::new(vector[
        MAX_TARGET_SUI_LIQUIDITY,
        LIQUIDITY_PROVISION,
        MEME_SALE_AMOUNT,
        100,
    ]);

    assert_eq!(stable.target_quote_liquidity(), MAX_TARGET_SUI_LIQUIDITY);
    assert_eq!(stable.liquidity_provision(), 6);
    assert_eq!(stable.meme_sale_amount(), 20);
}

#[test, expected_failure(abort_code = memez_errors::EInvalidConfig, location = memez_stable_config)]
fun test_new_invalid_config() {
    memez_stable_config::new(vector[MAX_TARGET_SUI_LIQUIDITY, LIQUIDITY_PROVISION]);
}
