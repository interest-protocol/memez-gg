#[test_only]
module memez_fun::memez_metadata_tests;

use memez_fun::{gg::{Self, GG}, memez_errors, memez_metadata, usdc::{Self, USDC}};
use std::unit_test::assert_eq;
use sui::{coin::CoinMetadata, test_scenario as ts, test_utils::destroy};

const ADMIN: address = @0x0;

#[test]
fun test_end_to_end() {
    let mut scenario = ts::begin(ADMIN);

    gg::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let coin_metadata = scenario.take_shared<CoinMetadata<GG>>();

    let mut metadata = memez_metadata::new(
        &coin_metadata,
        vector[b"Twitter".to_string()],
        vector[b"https://twitter.com/memez_fun".to_string()],
        scenario.ctx(),
    );

    assert_eq!(
        metadata.borrow()[&b"Twitter".to_string()],
        b"https://twitter.com/memez_fun".to_string(),
    );

    metadata.borrow_mut().insert(b"Telegram".to_string(), b"https://t.me/memez_fun".to_string());

    assert_eq!(metadata.borrow()[&b"Telegram".to_string()], b"https://t.me/memez_fun".to_string());
    assert_eq!(metadata.decimals(), 9);

    destroy(metadata);
    destroy(coin_metadata);
    scenario.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EInvalidMemeDecimals,
        location = memez_metadata,
    ),
]
fun test_invalid_decimals() {
    let mut scenario = ts::begin(ADMIN);

    usdc::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let coin_metadata = scenario.take_shared<CoinMetadata<USDC>>();

    let _metadata = memez_metadata::new(
        &coin_metadata,
        vector[b"Twitter".to_string()],
        vector[b"https://twitter.com/memez_fun".to_string()],
        scenario.ctx(),
    );

    abort
}
