#[test_only]
module memez_fun::memez_auction_config_tests;

use memez_fun::{memez_auction_model, memez_errors};
use std::unit_test::assert_eq;
use sui::test_utils::destroy;

const BURN_TAX: u64 = 200_000_000;

// @dev 10,000,000 = 1%
const DEV_ALLOCATION: u64 = 100;

// @dev 50,000,000 = 5%
const LIQUIDITY_PROVISION: u64 = 500;

const THIRTY_MINUTES_MS: u64 = 30 * 60 * 1_000;

const VIRTUAL_LIQUIDITY: u64 = 1_000__000_000_000;

const TARGET_SUI_LIQUIDITY: u64 = 10_000__000_000_000;

const SEED_LIQUIDITY: u64 = 10;

const MIN_SEED_LIQUIDITY: u64 = 100;

const STAKE_HOLDERS_ALLOCATION: u64 = 1_000;

const STAKE_HOLDERS_VESTING_PERIOD: u64 = THIRTY_MINUTES_MS * 10;

#[test]
fun test_end_to_end() {
    let auction = memez_auction_model::new(vector[
        THIRTY_MINUTES_MS,
        DEV_ALLOCATION,
        BURN_TAX,
        VIRTUAL_LIQUIDITY,
        TARGET_SUI_LIQUIDITY,
        LIQUIDITY_PROVISION,
        SEED_LIQUIDITY,
        STAKE_HOLDERS_ALLOCATION,
        STAKE_HOLDERS_VESTING_PERIOD,
    ]);

    let payload = auction.get(1000);

    assert_eq!(payload[0], THIRTY_MINUTES_MS);
    assert_eq!(payload[1], 10);
    assert_eq!(payload[2], BURN_TAX);
    assert_eq!(payload[3], VIRTUAL_LIQUIDITY);
    assert_eq!(payload[4], TARGET_SUI_LIQUIDITY);
    assert_eq!(payload[5], 50);
    assert_eq!(payload[6], MIN_SEED_LIQUIDITY);
    assert_eq!(payload[7], 100);
    assert_eq!(payload[8], STAKE_HOLDERS_VESTING_PERIOD);

    let payload = auction.get(1_000_000_000);

    assert_eq!(payload[0], THIRTY_MINUTES_MS);
    assert_eq!(payload[1], 10_000_000);
    assert_eq!(payload[2], BURN_TAX);
    assert_eq!(payload[3], VIRTUAL_LIQUIDITY);
    assert_eq!(payload[4], TARGET_SUI_LIQUIDITY);
    assert_eq!(payload[5], 50_000_000);
    assert_eq!(payload[6], 1_000_000);
    assert_eq!(payload[7], 100_000_000);
    assert_eq!(payload[8], STAKE_HOLDERS_VESTING_PERIOD);

    destroy(auction);
}

#[test, expected_failure(abort_code = memez_errors::EInvalidConfig, location = memez_auction_model)]
fun test_new_invalid_config() {
    let auction = memez_auction_model::new(vector[
        THIRTY_MINUTES_MS,
        DEV_ALLOCATION,
        BURN_TAX,
        VIRTUAL_LIQUIDITY,
        TARGET_SUI_LIQUIDITY,
        LIQUIDITY_PROVISION,
        SEED_LIQUIDITY,
        STAKE_HOLDERS_ALLOCATION,
    ]);

    destroy(auction);
}
