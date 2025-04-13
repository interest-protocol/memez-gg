#[test_only]
module memez_fun::memez_pump_config_tests;

use memez_fun::{memez_errors, memez_pump_config};
use std::unit_test::assert_eq;

const BURN_TAX: u64 = 5_000;

// @dev 50,000,000 = 6%
const LIQUIDITY_PROVISION: u64 = 600;

const VIRTUAL_LIQUIDITY: u64 = 1_000__000_000_000;

const TARGET_SUI_LIQUIDITY: u64 = 10_000__000_000_000;

public struct InvalidQuote()

#[test]
fun test_end_to_end() {
    let pump = memez_pump_config::new(vector[
        BURN_TAX,
        VIRTUAL_LIQUIDITY,
        TARGET_SUI_LIQUIDITY,
        LIQUIDITY_PROVISION,
        1_000,
    ]);

    assert_eq!(pump.burn_tax(), BURN_TAX);
    assert_eq!(pump.virtual_liquidity(), VIRTUAL_LIQUIDITY);
    assert_eq!(pump.target_quote_liquidity(), TARGET_SUI_LIQUIDITY);
    assert_eq!(pump.liquidity_provision(), 60);
}

#[test, expected_failure(abort_code = memez_errors::EInvalidConfig, location = memez_pump_config)]
fun test_new_invalid_config() {
    memez_pump_config::new(vector[
        BURN_TAX,
        VIRTUAL_LIQUIDITY,
        TARGET_SUI_LIQUIDITY,
        LIQUIDITY_PROVISION,
    ]);
}

#[test, expected_failure(abort_code = memez_errors::EInvalidBurnTax, location = memez_pump_config)]
fun test_new_invalid_config_2() {
    memez_pump_config::new(vector[
        7_000,
        VIRTUAL_LIQUIDITY,
        TARGET_SUI_LIQUIDITY,
        LIQUIDITY_PROVISION,
        1_000,
    ]);
}
