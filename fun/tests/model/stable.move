#[test_only]
module memez_fun::memez_stable_config_tests;

use memez_fun::{memez_errors, memez_stable_model};
use std::unit_test::assert_eq;
use sui::test_utils::destroy;

// @dev 50,000,000 = 6%
const LIQUIDITY_PROVISION: u64 = 600;

const MEME_SALE_AMOUNT: u64 = 2_000;

const MAX_TARGET_SUI_LIQUIDITY: u64 = 1_000_000_000;

#[test]
fun test_end_to_end() {
    let auction = memez_stable_model::new(vector[
        MAX_TARGET_SUI_LIQUIDITY,
        LIQUIDITY_PROVISION,
        MEME_SALE_AMOUNT,
    ]);

    let payload = auction.get(100);

    assert_eq!(payload[0], MAX_TARGET_SUI_LIQUIDITY);
    assert_eq!(payload[1], 6);
    assert_eq!(payload[2], 20);

    destroy(auction);
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EInvalidConfig,
        location = memez_stable_model,
    ),
]
fun test_new_invalid_config() {
    let auction = memez_stable_model::new(vector[MAX_TARGET_SUI_LIQUIDITY, LIQUIDITY_PROVISION]);

    destroy(auction);
}
