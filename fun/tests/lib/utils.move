#[test_only]
module memez_fun::memez_utils_tests;

use std::unit_test::assert_eq;
use memez_fun::{memez_errors, memez_utils};
use sui::{balance, coin::{Coin, mint_for_testing}, test_scenario as ts};

public struct Meme()

const DEAD_ADDRESS: address = @0x0;

#[test]
fun test_pow_9() {
    assert_eq!(memez_utils::pow_9(), 1__000_000_000);
}

#[test]
fun test_assert_coin_has_value() {
    let mut ctx = tx_context::dummy();

    let coin = mint_for_testing<Meme>(1000, &mut ctx);
    let value = memez_utils::assert_coin_has_value(&coin);

    assert_eq!(value, coin.burn_for_testing());
}

#[test, expected_failure(abort_code = memez_errors::EZeroCoin, location = memez_utils)]
fun test_assert_coin_has_value_zero() {
    let mut ctx = tx_context::dummy();
    let coin = mint_for_testing<Meme>(0, &mut ctx);

    memez_utils::assert_coin_has_value(&coin);

    coin.destroy_zero();
}

#[test]
fun test_destroy_or_burn() {
    let mut scenario = ts::begin(DEAD_ADDRESS);
    let mut balance = balance::create_for_testing<Meme>(1000);

    memez_utils::destroy_or_burn(&mut balance, scenario.ctx());

    balance.destroy_zero();

    scenario.next_epoch(DEAD_ADDRESS);

    let meme_coin = scenario.take_from_sender<Coin<Meme>>();

    assert_eq!(meme_coin.burn_for_testing(), 1000);

    let mut balance_zero = balance::zero<Meme>();

    memez_utils::destroy_or_burn(&mut balance_zero, scenario.ctx());

    balance_zero.destroy_zero();

    scenario.end();
}

#[test]
fun test_destroy_or_return() {
    let mut scenario = ts::begin(DEAD_ADDRESS);

    memez_utils::destroy_or_return(mint_for_testing<Meme>(1000, scenario.ctx()), scenario.ctx());

    scenario.next_tx(DEAD_ADDRESS);

    let meme_coin = scenario.take_from_sender<Coin<Meme>>();

    assert_eq!(meme_coin.burn_for_testing(), 1000);

    scenario.next_tx(DEAD_ADDRESS);

    let zero_coin = mint_for_testing<Meme>(0, scenario.ctx());

    memez_utils::destroy_or_return(zero_coin, scenario.ctx());

    scenario.end();
}

#[test]
fun test_slippage() {
    memez_utils::assert_slippage(100, 100);
    memez_utils::assert_slippage(100, 99);
}

#[test]
fun test_validate_bps() {
    memez_utils::validate_bps(vector[2_500, 2_500, 2_500, 2_500]);
    memez_utils::validate_bps(vector[5_000, 5_000]);
}

#[test, expected_failure(abort_code = memez_errors::ESlippage, location = memez_utils)]
fun test_slippage_error() {
    memez_utils::assert_slippage(100, 101);
    memez_utils::assert_slippage(100, 99);
}

#[test, expected_failure(abort_code = memez_errors::EInvalidPercentages, location = memez_utils)]
fun test_validate_bps_invalid_total() {
    memez_utils::validate_bps(vector[2_500, 2_500, 2_500, 2_500 - 1]);
}
