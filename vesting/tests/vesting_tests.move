#[test_only]
module memez_vesting::memez_vesting_tests;

use memez_vesting::{memez_vesting, memez_vesting_constants};
use sui::{clock, coin, sui::SUI, test_utils::{assert_eq, destroy}};

#[test]
fun test_end_to_end() {
    let mut ctx = tx_context::dummy();

    let start = 1 + memez_vesting_constants::delay_margin_ms!();
    let duration = 8;
    let coin_amount = 1234567890;

    let total_coin = coin::mint_for_testing<SUI>(coin_amount, &mut ctx);
    let mut clock = clock::create_for_testing(&mut ctx);

    clock.increment_for_testing(memez_vesting_constants::delay_margin_ms!());

    let mut wallet = memez_vesting::new(&clock, total_coin, start, duration, &mut ctx);

    clock.increment_for_testing(1);

    assert_eq(wallet.balance(), coin_amount);
    assert_eq(wallet.start(), start);
    assert_eq(wallet.released(), 0);
    assert_eq(wallet.duration(), duration);

    // Clock is at 2
    clock.increment_for_testing(1);

    let first_claim = coin_amount / 8;
    assert_eq(
        coin::burn_for_testing(wallet.claim(&clock, &mut ctx)),
        first_claim,
    );

    // Clock is at 7
    clock.increment_for_testing(5);

    let second_claim = (6 * coin_amount / 8) - first_claim;
    assert_eq(
        coin::burn_for_testing(wallet.claim(&clock, &mut ctx)),
        second_claim,
    );

    // Clock is at 9
    clock.increment_for_testing(2);

    let claim = coin_amount - second_claim - first_claim;
    assert_eq(
        coin::burn_for_testing(wallet.claim(&clock, &mut ctx)),
        claim,
    );

    wallet.destroy_zero();
    clock.destroy_for_testing();
}

#[test]
#[expected_failure]
fun test_destroy_non_zero_wallet() {
    let mut ctx = tx_context::dummy();

    let end = 8;
    let coin_amount = 1234567890;

    let total_coin = coin::mint_for_testing<SUI>(coin_amount, &mut ctx);
    let mut clock = clock::create_for_testing(&mut ctx);

    clock.increment_for_testing(memez_vesting_constants::delay_margin_ms!());

    let wallet = memez_vesting::new(&clock, total_coin, 0, end, &mut ctx);

    wallet.destroy_zero();
    clock::destroy_for_testing(clock);
}

#[test]
#[expected_failure(abort_code = memez_vesting::EZeroDuration)]
fun test_zero_duration() {
    let mut ctx = tx_context::dummy();

    let mut clock = clock::create_for_testing(&mut ctx);

    clock.increment_for_testing(memez_vesting_constants::delay_margin_ms!());

    let coin_amount = 1234567890;
    let total_coin = coin::mint_for_testing<SUI>(coin_amount, &mut ctx);

    let wallet = memez_vesting::new(&clock, total_coin, 1, 0, &mut ctx);

    clock::destroy_for_testing(clock);
    destroy(wallet);
}

#[test]
#[expected_failure(abort_code = memez_vesting::EZeroAllocation)]
fun test_zero_allocation() {
    let mut ctx = tx_context::dummy();

    let mut clock = clock::create_for_testing(&mut ctx);

    clock.increment_for_testing(memez_vesting_constants::delay_margin_ms!());

    let coin_amount = 0;
    let total_coin = coin::mint_for_testing<SUI>(coin_amount, &mut ctx);

    let wallet = memez_vesting::new(&clock, total_coin, 1, 8, &mut ctx);

    clock::destroy_for_testing(clock);
    destroy(wallet);
}

#[test]
#[expected_failure(abort_code = memez_vesting::EZeroStart)]
fun test_zero_start() {
    let mut ctx = tx_context::dummy();

    let mut clock = clock::create_for_testing(&mut ctx);

    clock.increment_for_testing(memez_vesting_constants::delay_margin_ms!());

    let coin_amount = 1234567890;
    let total_coin = coin::mint_for_testing<SUI>(coin_amount, &mut ctx);

    clock.increment_for_testing(1);

    let wallet = memez_vesting::new(&clock, total_coin, 0, 8, &mut ctx);

    clock::destroy_for_testing(clock);
    destroy(wallet);
}
