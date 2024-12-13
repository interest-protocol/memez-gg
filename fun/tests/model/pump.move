#[test_only]
module memez_fun::memez_pump_config_tests;

use memez_fun::{memez_errors, memez_pump_model};
use std::unit_test::assert_eq;
use sui::test_utils::destroy;

const BURN_TAX: u64 = 200_000_000;

// @dev 50,000,000 = 6%
const LIQUIDITY_PROVISION: u64 = 600;

const VIRTUAL_LIQUIDITY: u64 = 1_000__000_000_000;

const TARGET_SUI_LIQUIDITY: u64 = 10_000__000_000_000;

// @dev 200 = 2%
const DEV_ALLOCATION: u64 = 200;

// @dev 100 = 100 days
const DEV_VESTING_PERIOD: u64 = 86400000 * 2;

#[test]
fun test_end_to_end() {
    let auction = memez_pump_model::new(vector[
        BURN_TAX,
        VIRTUAL_LIQUIDITY,
        TARGET_SUI_LIQUIDITY,
        LIQUIDITY_PROVISION,
        DEV_ALLOCATION,
        DEV_VESTING_PERIOD,
    ]);

    let payload = auction.get(1000);

    assert_eq!(payload[0], BURN_TAX);
    assert_eq!(payload[1], VIRTUAL_LIQUIDITY);
    assert_eq!(payload[2], TARGET_SUI_LIQUIDITY);
    assert_eq!(payload[3], 60);
    assert_eq!(payload[4], 20);
    assert_eq!(payload[5], DEV_VESTING_PERIOD);

    destroy(auction);
}

#[test, expected_failure(abort_code = memez_errors::EInvalidConfig, location = memez_pump_model)]
fun test_new_invalid_config() {
    let auction = memez_pump_model::new(vector[
        BURN_TAX,
        VIRTUAL_LIQUIDITY,
        TARGET_SUI_LIQUIDITY,
        LIQUIDITY_PROVISION,
        0,
    ]);

    destroy(auction);
}
