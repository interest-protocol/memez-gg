#[test_only]
module memez_vesting::vesting_wallet_tests;

use sui::{
    coin,
    clock,
    sui::SUI,
    test_utils::assert_eq
};

use memez_vesting::vesting_wallet;

#[test]
fun test_end_to_end() {
    let mut ctx = tx_context::dummy();

    let start = 1;
    let duration = 8;
    let coin_amount = 1234567890;

    let total_coin = coin::mint_for_testing<SUI>(coin_amount, &mut ctx);
    let mut clock = clock::create_for_testing(&mut ctx);

    clock.increment_for_testing(start);
    
    let mut wallet = vesting_wallet::new(total_coin, &clock, duration, &mut ctx);

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
    let clock = clock::create_for_testing(&mut ctx);

    let wallet = vesting_wallet::new(total_coin, &clock, end, &mut ctx);

    wallet.destroy_zero();
    clock::destroy_for_testing(clock);
}
