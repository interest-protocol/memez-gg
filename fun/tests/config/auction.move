#[test_only]
module memez_fun::memez_auction_config_tests;

use memez_fun::{memez_auction_config, memez_errors};
use std::{type_name, unit_test::assert_eq};
use sui::test_utils::destroy;

// @dev 50,000,000 = 5%
const LIQUIDITY_PROVISION: u64 = 500;

const THIRTY_MINUTES_MS: u64 = 30 * 60 * 1_000;

const TARGET_SUI_LIQUIDITY: u64 = 10_000__000_000_000;

const SEED_LIQUIDITY: u64 = 10;

const MIN_SEED_LIQUIDITY: u64 = 100;

public struct Quote()

public struct InvalidQuote()

#[test]
fun test_end_to_end() {
    let auction = memez_auction_config::new<Quote>(vector[
        THIRTY_MINUTES_MS,
        TARGET_SUI_LIQUIDITY,
        LIQUIDITY_PROVISION,
        SEED_LIQUIDITY,
    ]);

    let payload = auction.get<Quote>(1000);

    assert_eq!(payload[0], THIRTY_MINUTES_MS);
    assert_eq!(payload[1], TARGET_SUI_LIQUIDITY);
    assert_eq!(payload[2], 50);
    assert_eq!(payload[3], MIN_SEED_LIQUIDITY);
    assert_eq!(auction.quote_type(), type_name::get<Quote>());

    let payload = auction.get<Quote>(1_000_000_000);

    assert_eq!(payload[0], THIRTY_MINUTES_MS);
    assert_eq!(payload[1], TARGET_SUI_LIQUIDITY);
    assert_eq!(payload[2], 50_000_000);
    assert_eq!(payload[3], 1_000_000);
    assert_eq!(auction.quote_type(), type_name::get<Quote>());

    destroy(auction);
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EInvalidConfig,
        location = memez_auction_config,
    ),
]
fun test_new_invalid_config() {
    let auction = memez_auction_config::new<Quote>(vector[
        THIRTY_MINUTES_MS,
        TARGET_SUI_LIQUIDITY,
        LIQUIDITY_PROVISION,
    ]);

    destroy(auction);
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EInvalidQuoteType,
        location = memez_auction_config,
    ),
]
fun test_new_invalid_quote() {
    let auction = memez_auction_config::new<Quote>(vector[
        THIRTY_MINUTES_MS,
        TARGET_SUI_LIQUIDITY,
        LIQUIDITY_PROVISION,
        SEED_LIQUIDITY,
    ]);

    auction.get<InvalidQuote>(1_000_000_000);

    destroy(auction);
}
