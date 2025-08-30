#[test_only]
module memez_vesting::memez_soulbound_vesting_tests;

use memez_vesting::memez_soulbound_vesting::{Self, MemezSoulBoundVesting};
use sui::{
    clock::{Self, Clock},
    coin,
    sui::SUI,
    test_scenario::{Self as ts, Scenario},
    test_utils::{assert_eq, destroy}
};

const SENDER: address = @0x1;

const OWNER: address = @0x2;

public struct Env {
    scenario: Scenario,
    clock: Clock,
}

#[test]
fun test_end_to_end() {
    let mut env = start();

    let start = 1;
    let duration = 8;
    let coin_amount = 1234567890;

    let total_coin = coin::mint_for_testing<SUI>(coin_amount, env.scenario.ctx());

    let wallet = memez_soulbound_vesting::new(
        &env.clock,
        total_coin,
        1,
        duration,
        OWNER,
        env.scenario.ctx(),
    );

    env.clock.increment_for_testing(start);

    assert_eq(wallet.balance(), coin_amount);
    assert_eq(wallet.start(), start);
    assert_eq(wallet.released(), 0);
    assert_eq(wallet.duration(), duration);

    wallet.transfer_to_owner();

    env.scenario.next_tx(OWNER);

    let mut wallet = env.scenario.take_from_sender<MemezSoulBoundVesting<SUI>>();

    // Clock is at 2
    env.clock.increment_for_testing(1);

    let first_claim = coin_amount / 8;
    assert_eq(
        coin::burn_for_testing(wallet.claim(&env.clock, env.scenario.ctx())),
        first_claim,
    );

    // Clock is at 7
    env.clock.increment_for_testing(5);

    let second_claim = (6 * coin_amount / 8) - first_claim;
    assert_eq(
        coin::burn_for_testing(wallet.claim(&env.clock, env.scenario.ctx())),
        second_claim,
    );

    // Clock is at 9
    env.clock.increment_for_testing(2);

    let claim = coin_amount - second_claim - first_claim;
    assert_eq(
        coin::burn_for_testing(wallet.claim(&env.clock, env.scenario.ctx())),
        claim,
    );

    wallet.destroy_zero();

    env.end();
}

// #[test]
// #[expected_failure]
// fun test_destroy_non_zero_wallet() {
//     let mut ctx = tx_context::dummy();

//     let end = 8;
//     let coin_amount = 1234567890;

//     let total_coin = coin::mint_for_testing<SUI>(coin_amount, &mut ctx);
//     let clock = clock::create_for_testing(&mut ctx);

//     let wallet = memez_soulbound_vesting::new(&clock,total_coin, 0, end, &mut ctx);

//     wallet.destroy_zero();
//     clock::destroy_for_testing(clock);
// }

// #[test]
// #[expected_failure(abort_code = memez_soulbound_vesting::EZeroDuration)]
// fun test_zero_duration() {
//     let mut ctx = tx_context::dummy();

//     let clock = clock::create_for_testing(&mut ctx);

//     let coin_amount = 1234567890;
//     let total_coin = coin::mint_for_testing<SUI>(coin_amount, &mut ctx);

//     let wallet = memez_soulbound_vesting::new(&clock, total_coin, 1, 0, &mut ctx);

//     clock::destroy_for_testing(clock);
//     destroy(wallet);
// }

// #[test]
// #[expected_failure(abort_code = memez_soulbound_vesting::EZeroAllocation)]
// fun test_zero_allocation() {
//     let mut ctx = tx_context::dummy();

//     let clock = clock::create_for_testing(&mut ctx);

//     let coin_amount = 0;
//     let total_coin = coin::mint_for_testing<SUI>(coin_amount, &mut ctx);

//     let wallet = memez_soulbound_vesting::new(&clock, total_coin, 1, 8, &mut ctx);

//     clock::destroy_for_testing(clock);
//     destroy(wallet);
// }

// #[test]
// #[expected_failure(abort_code = memez_soulbound_vesting::EZeroStart)]
// fun test_zero_start() {
//     let mut ctx = tx_context::dummy();

//     let mut clock = clock::create_for_testing(&mut ctx);

//     let coin_amount = 1234567890;
//     let total_coin = coin::mint_for_testing<SUI>(coin_amount, &mut ctx);

//     clock.increment_for_testing(1);

//     let wallet = memez_soulbound_vesting::new(&clock, total_coin, 0, 8, &mut ctx);

//     clock::destroy_for_testing(clock);
//     destroy(wallet);
// }

fun start(): Env {
    let mut scenario = ts::begin(SENDER);

    let clock = clock::create_for_testing(scenario.ctx());

    Env { scenario, clock }
}

fun end(env: Env) {
    destroy(env);
}
