#[test_only]
module memez_fun::memez_utils_tests;

use interest_bps::bps;
use ipx_coin_standard::ipx_coin_standard::IPXTreasuryStandard;
use memez_fun::{memez_errors, memez_utils};
use std::unit_test::assert_eq;
use sui::{
    balance,
    coin::{Self, Coin, mint_for_testing},
    sui::SUI,
    test_scenario as ts,
    test_utils::destroy
};

public struct Meme()

const DEAD_ADDRESS: address = @0x0;

const ADMIN: address = @0x1;

const TOTAL_MEME_SUPPLY: u64 = 1_000_000_000__000_000_000;

#[test]
fun test_assert_coin_has_value() {
    let mut ctx = tx_context::dummy();

    let coin = mint_for_testing<Meme>(1000, &mut ctx);
    let value = memez_utils::assert_coin_has_value!(&coin);

    assert_eq!(value, coin.burn_for_testing());
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EZeroCoin,
        location = memez_fun::memez_utils_tests,
    ),
]
fun test_assert_coin_has_value_zero() {
    let mut ctx = tx_context::dummy();
    let coin = mint_for_testing<Meme>(0, &mut ctx);

    memez_utils::assert_coin_has_value!(&coin);

    coin.destroy_zero();
}

#[test]
fun test_destroy_or_burn() {
    let mut scenario = ts::begin(DEAD_ADDRESS);
    let mut balance = balance::create_for_testing<Meme>(1000);

    memez_utils::destroy_or_burn!(&mut balance, scenario.ctx());

    balance.destroy_zero();

    scenario.next_epoch(DEAD_ADDRESS);

    let meme_coin = scenario.take_from_sender<Coin<Meme>>();

    assert_eq!(meme_coin.burn_for_testing(), 1000);

    let mut balance_zero = balance::zero<Meme>();

    memez_utils::destroy_or_burn!(&mut balance_zero, scenario.ctx());

    balance_zero.destroy_zero();

    scenario.end();
}

#[test]
fun test_destroy_or_return() {
    let mut scenario = ts::begin(DEAD_ADDRESS);

    memez_utils::destroy_or_return!(mint_for_testing<Meme>(1000, scenario.ctx()), scenario.ctx());

    scenario.next_tx(DEAD_ADDRESS);

    let meme_coin = scenario.take_from_sender<Coin<Meme>>();

    assert_eq!(meme_coin.burn_for_testing(), 1000);

    scenario.next_tx(DEAD_ADDRESS);

    let zero_coin = mint_for_testing<Meme>(0, scenario.ctx());

    memez_utils::destroy_or_return!(zero_coin, scenario.ctx());

    scenario.end();
}

#[test]
fun test_slippage() {
    memez_utils::assert_slippage!(100, 100);
    memez_utils::assert_slippage!(100, 99);
}

#[test]
fun test_validate_bps() {
    memez_utils::validate_bps!(vector[2_500, 2_500, 2_500, 2_500]);
    memez_utils::validate_bps!(vector[5_000, 5_000]);
}

#[test]
fun set_up_treasury() {
    let mut scenario = ts::begin(DEAD_ADDRESS);

    let treasury_cap = coin::create_treasury_cap_for_testing<SUI>(scenario.ctx());

    let (meme_treasury_address, metadata_cap, meme_balance) = memez_utils::new_treasury!(
        treasury_cap,
        TOTAL_MEME_SUPPLY,
        scenario.ctx(),
    );

    scenario.next_epoch(ADMIN);

    let meme_treasury = scenario.take_shared<IPXTreasuryStandard>();

    assert_eq!(object::id(&meme_treasury).to_address(), meme_treasury_address);

    assert_eq!(metadata_cap.ipx_treasury(), meme_treasury_address);
    assert_eq!(meme_balance.value(), TOTAL_MEME_SUPPLY);
    assert_eq!(meme_treasury.total_supply<SUI>(), TOTAL_MEME_SUPPLY);
    assert_eq!(meme_treasury.can_burn(), true);

    destroy(meme_balance);
    destroy(meme_treasury);

    destroy(metadata_cap);

    scenario.end();
}

#[test]
fun send_referrer_fee() {
    let mut scenario = ts::begin(DEAD_ADDRESS);

    let mut coin = mint_for_testing<Meme>(1000, scenario.ctx());

    let referrer_address = @0x2;

    let fee = bps::new(1_000);

    let payment_value = memez_utils::send_referrer_fee!(
        &mut coin,
        option::none(),
        fee,
        scenario.ctx(),
    );

    assert_eq!(payment_value, 0);

    let payment_value = memez_utils::send_referrer_fee!(
        &mut coin,
        option::some(referrer_address),
        fee,
        scenario.ctx(),
    );

    scenario.next_epoch(referrer_address);

    let referrer_coin = scenario.take_from_sender<Coin<Meme>>();

    assert_eq!(payment_value, 100);
    assert_eq!(referrer_coin.burn_for_testing(), 100);
    assert_eq!(coin.burn_for_testing(), 900);

    scenario.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EZeroTotalSupply,
        location = memez_fun::memez_utils_tests,
    ),
]
fun set_up_treasury_zero_total_supply() {
    let mut scenario = ts::begin(DEAD_ADDRESS);

    let treasury_cap = coin::create_treasury_cap_for_testing<SUI>(scenario.ctx());

    let (_meme_treasury_address, _metadata_cap, _meme_balance) = memez_utils::new_treasury!(
        treasury_cap,
        0,
        scenario.ctx(),
    );

    abort
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EPreMintNotAllowed,
        location = memez_fun::memez_utils_tests,
    ),
]
fun set_up_treasury_pre_mint() {
    let mut scenario = ts::begin(DEAD_ADDRESS);

    let mut treasury_cap = coin::create_treasury_cap_for_testing<SUI>(scenario.ctx());

    treasury_cap.mint(100, scenario.ctx()).burn_for_testing();

    let (_address, _metadata_cap, _meme_balance) = memez_utils::new_treasury!(
        treasury_cap,
        TOTAL_MEME_SUPPLY,
        scenario.ctx(),
    );

    abort
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::ESlippage,
        location = memez_fun::memez_utils_tests,
    ),
]
fun test_slippage_error() {
    memez_utils::assert_slippage!(100, 101);
    memez_utils::assert_slippage!(100, 99);
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EInvalidPercentages,
        location = memez_fun::memez_utils_tests,
    ),
]
fun test_validate_bps_invalid_total() {
    memez_utils::validate_bps!(vector[2_500, 2_500, 2_500, 2_500 - 1]);
}
