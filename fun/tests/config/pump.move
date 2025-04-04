#[test_only]
module memez_fun::memez_pump_config_tests;

use memez_fun::{memez_errors, memez_pump_config};
use std::{type_name, unit_test::assert_eq};
use sui::test_utils::destroy;

const BURN_TAX: u64 = 200_000_000;

// @dev 50,000,000 = 6%
const LIQUIDITY_PROVISION: u64 = 600;

const VIRTUAL_LIQUIDITY: u64 = 1_000__000_000_000;

const TARGET_SUI_LIQUIDITY: u64 = 10_000__000_000_000;

public struct Quote()

public struct InvalidQuote()

#[test]
fun test_end_to_end() {
    let auction = memez_pump_config::new<Quote>(vector[
        BURN_TAX,
        VIRTUAL_LIQUIDITY,
        TARGET_SUI_LIQUIDITY,
        LIQUIDITY_PROVISION,
    ]);

    let payload = auction.get<Quote>(1000);

    assert_eq!(payload[0], BURN_TAX);
    assert_eq!(payload[1], VIRTUAL_LIQUIDITY);
    assert_eq!(payload[2], TARGET_SUI_LIQUIDITY);
    assert_eq!(payload[3], 60);
    assert_eq!(auction.quote_type(), type_name::get<Quote>());

    destroy(auction);
}

#[test, expected_failure(abort_code = memez_errors::EInvalidConfig, location = memez_pump_config)]
fun test_new_invalid_config() {
    let auction = memez_pump_config::new<Quote>(vector[
        BURN_TAX,
        VIRTUAL_LIQUIDITY,
        TARGET_SUI_LIQUIDITY,
        LIQUIDITY_PROVISION,
        0,
    ]);

    destroy(auction);
}

#[test, expected_failure(abort_code = memez_errors::EInvalidQuoteType, location = memez_pump_config)]
fun test_new_invalid_quote() {
    let auction = memez_pump_config::new<Quote>(vector[
        BURN_TAX,
        VIRTUAL_LIQUIDITY,
        TARGET_SUI_LIQUIDITY,
        LIQUIDITY_PROVISION,
    ]);

    auction.get<InvalidQuote>(1000);

    destroy(auction);
}
