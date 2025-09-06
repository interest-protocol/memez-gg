#[test_only]
module memez_vesting::memez_soulbound_vesting_tests;

use memez_vesting::{
    memez_soulbound_vesting::{Self, MemezSoulBoundVesting},
    memez_vesting_errors,
    memez_vesting_events::{Self, Event, New, Claimed, Destroyed}
};
use sui::{
    clock::{Self, Clock},
    coin,
    event,
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

    let start = 1 + memez_vesting::memez_vesting_constants::delay_margin_ms!();
    let duration = 8;
    let coin_amount = 1234567890;

    let total_coin = coin::mint_for_testing<SUI>(coin_amount, env.scenario.ctx());

    let wallet = memez_soulbound_vesting::new(
        &env.clock,
        total_coin,
        start,
        duration,
        OWNER,
        env.scenario.ctx(),
    );

    assert_eq(event::num_events(), 1);

    let new_events = event::events_by_type<Event<New>>();

    assert_eq(new_events.length(), 1);

    assert_eq(
        new_events[0],
        memez_vesting_events::new_event<SUI>(wallet.id(), OWNER, coin_amount, start, duration),
    );

    env.clock.increment_for_testing(1);

    assert_eq(wallet.balance(), coin_amount);
    assert_eq(wallet.start(), start);
    assert_eq(wallet.released(), 0);
    assert_eq(wallet.duration(), duration);

    wallet.transfer_to_owner();

    // Resets the events counter
    env.scenario.next_tx(OWNER);

    let mut wallet = env.scenario.take_from_sender<MemezSoulBoundVesting<SUI>>();

    let wallet_id = wallet.id();

    // Clock is at 2
    env.clock.increment_for_testing(1);

    let first_claim = coin_amount / 8;

    assert_eq(
        coin::burn_for_testing(wallet.claim(&env.clock, env.scenario.ctx())),
        first_claim,
    );

    assert_eq(event::num_events(), 1);

    let claimed_events = event::events_by_type<Event<Claimed>>();

    assert_eq(claimed_events.length(), 1);

    assert_eq(
        claimed_events[0],
        memez_vesting_events::claimed_event<SUI>(wallet_id, first_claim),
    );

    // Clock is at 7
    env.clock.increment_for_testing(5);

    let second_claim = (6 * coin_amount / 8) - first_claim;
    assert_eq(
        coin::burn_for_testing(wallet.claim(&env.clock, env.scenario.ctx())),
        second_claim,
    );

    assert_eq(event::num_events(), 2);

    let claimed_events = event::events_by_type<Event<Claimed>>();

    assert_eq(claimed_events.length(), 2);

    assert_eq(
        claimed_events[1],
        memez_vesting_events::claimed_event<SUI>(
            wallet_id,
            second_claim,
        ),
    );

    // Clock is at 9
    env.clock.increment_for_testing(2);

    let claim = coin_amount - second_claim - first_claim;
    assert_eq(
        coin::burn_for_testing(wallet.claim(&env.clock, env.scenario.ctx())),
        claim,
    );

    assert_eq(event::num_events(), 3);

    let claimed_events = event::events_by_type<Event<Claimed>>();

    assert_eq(claimed_events.length(), 3);

    assert_eq(claimed_events[2], memez_vesting_events::claimed_event<SUI>(wallet_id, claim));

    wallet.destroy_zero();

    assert_eq(event::num_events(), 4);

    let destroyed_events = event::events_by_type<Event<Destroyed>>();

    assert_eq(destroyed_events.length(), 1);

    assert_eq(destroyed_events[0], memez_vesting_events::destroyed_event<SUI>(wallet_id));

    env.end();
}

#[test]
#[expected_failure]
fun test_new_zero_allocation() {
    let mut env = start();

    let end = 8;
    let coin_amount = 1234567890;

    let total_coin = coin::mint_for_testing<SUI>(coin_amount, env.scenario.ctx());

    let wallet = memez_soulbound_vesting::new(
        &env.clock,
        total_coin,
        0,
        end,
        OWNER,
        env.scenario.ctx(),
    );

    wallet.destroy_zero();

    env.end();
}

#[test]
#[
    expected_failure(
        abort_code = memez_vesting_errors::EZeroDuration,
        location = memez_vesting::memez_soulbound_vesting,
    ),
]
fun test_zero_duration() {
    let mut env = start();

    let coin_amount = 1234567890;
    let total_coin = coin::mint_for_testing<SUI>(coin_amount, env.scenario.ctx());

    let _wallet = memez_soulbound_vesting::new(
        &env.clock,
        total_coin,
        1,
        0,
        OWNER,
        env.scenario.ctx(),
    );

    abort
}

#[test]
#[
    expected_failure(
        abort_code = memez_vesting_errors::EZeroAllocation,
        location = memez_vesting::memez_soulbound_vesting,
    ),
]
fun test_zero_allocation() {
    let mut env = start();

    let coin_amount = 0;
    let total_coin = coin::mint_for_testing<SUI>(coin_amount, env.scenario.ctx());

    let _wallet = memez_soulbound_vesting::new(
        &env.clock,
        total_coin,
        1,
        8,
        OWNER,
        env.scenario.ctx(),
    );

    abort
}

#[test]
#[
    expected_failure(
        abort_code = memez_vesting_errors::EInvalidStart,
        location = memez_vesting::memez_soulbound_vesting,
    ),
]
fun test_zero_start() {
    let mut env = start();

    let coin_amount = 1234567890;
    let total_coin = coin::mint_for_testing<SUI>(coin_amount, env.scenario.ctx());

    env.clock.increment_for_testing(1);

    let _wallet = memez_soulbound_vesting::new(
        &env.clock,
        total_coin,
        0,
        8,
        OWNER,
        env.scenario.ctx(),
    );

    abort
}

fun start(): Env {
    let mut scenario = ts::begin(SENDER);

    let mut clock = clock::create_for_testing(scenario.ctx());

    clock.increment_for_testing(memez_vesting::memez_vesting_constants::delay_margin_ms!());

    Env { scenario, clock }
}

fun end(env: Env) {
    destroy(env);
}
