#[test_only]
module memez_fun::memez_auction_config_tests;

use memez_fun::{memez_auction_config, memez_errors};
use std::unit_test::assert_eq;

// @dev 50,000,000 = 5%
const LIQUIDITY_PROVISION: u64 = 500;

const THIRTY_MINUTES_MS: u64 = 30 * 60 * 1_000;

const TARGET_SUI_LIQUIDITY: u64 = 10_000__000_000_000;

const SEED_LIQUIDITY: u64 = 10;

const MIN_SEED_LIQUIDITY: u64 = 100;

public struct InvalidQuote()

#[test]
fun test_end_to_end() {
    let auction_1 = memez_auction_config::new(vector[
        THIRTY_MINUTES_MS,
        TARGET_SUI_LIQUIDITY,
        LIQUIDITY_PROVISION,
        SEED_LIQUIDITY,
        1_000
    ]);

    let auction_2 = memez_auction_config::new(vector[
        THIRTY_MINUTES_MS,
        TARGET_SUI_LIQUIDITY,
        LIQUIDITY_PROVISION,
        SEED_LIQUIDITY,
        1_000_000_000
    ]);

    assert_eq!(auction_1.auction_duration(), THIRTY_MINUTES_MS);
    assert_eq!(auction_1.target_quote_liquidity(), TARGET_SUI_LIQUIDITY);
    assert_eq!(auction_1.liquidity_provision(), 50);
    assert_eq!(auction_1.seed_liquidity(), MIN_SEED_LIQUIDITY);
    assert_eq!(auction_2.liquidity_provision(), 50_000_000);
    assert_eq!(auction_2.seed_liquidity(), 1_000_000);
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EInvalidConfig,
        location = memez_auction_config,
    ),
]
fun test_new_invalid_config() {
    memez_auction_config::new(vector[
        THIRTY_MINUTES_MS,
        TARGET_SUI_LIQUIDITY,
        LIQUIDITY_PROVISION,
        SEED_LIQUIDITY,
    ]);
}
