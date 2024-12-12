#[test_only]
module memez_fun::memez_fees_tests;

use memez_fun::{memez_errors, memez_fees::{Self, MemezFees}, memez_utils};
use sui::test_utils::assert_eq;
use sui::{coin::{mint_for_testing, Coin}, test_scenario as ts};

const POW_9: u64 = 1_000_000_000;

const INTEREST: address = @0x5;

const INTEGRATOR: address = @0x6;

const STAKE_HOLDER_1: address = @0x7;

const STAKE_HOLDER_2: address = @0x8;

const VESTING_PERIOD: u64 = 101;

public struct Meme()

#[test]
fun test_new() {
    let payloads = default_fees().payloads();

    assert_eq(payloads[0].payload_value(), 2 * POW_9);
    assert_eq(payloads[1].payload_value(), 100);
    assert_eq(payloads[2].payload_value(), 200 * POW_9);
    assert_eq(payloads[3].payload_value(), 200);

    assert_eq(payloads[0].payload_percentages(), vector[7_000, 3_000]);
    assert_eq(payloads[1].payload_percentages(), vector[5_000, 2_500, 2_500]);
    assert_eq(payloads[2].payload_percentages(), vector[4_000, 1_000, 2_500, 2_500]);
    assert_eq(payloads[3].payload_percentages(), vector[3_000, 3_500, 3_500]);

    assert_eq(payloads[0].payload_recipients(), vector[INTEGRATOR, INTEREST]);
    assert_eq(payloads[1].payload_recipients(), vector[INTEGRATOR]);
    assert_eq(payloads[2].payload_recipients(), vector[INTEGRATOR, INTEREST]);
    assert_eq(payloads[3].payload_recipients(), vector[INTEGRATOR]);
}

#[test]
fun test_calculate() {
    let fees = default_fees();

    let creation_fee = fees.creation();
    let swap_fee = fees.swap(vector[STAKE_HOLDER_1, STAKE_HOLDER_2]);
    let migration_fee = fees.migration(vector[STAKE_HOLDER_1, STAKE_HOLDER_2]);
    let allocation_fee = fees.allocation(vector[STAKE_HOLDER_1, STAKE_HOLDER_2], VESTING_PERIOD);

    assert_eq(creation_fee.recipients().length(), 2);
    assert_eq(swap_fee.recipients().length(), 3);
    assert_eq(migration_fee.recipients().length(), 4);
    assert_eq(allocation_fee.recipients().length(), 3);

    // Test Values

    assert_eq(creation_fee.value(), 2 * POW_9);
    assert_eq(swap_fee.value(), 100);
    assert_eq(migration_fee.value(), 200 * POW_9);
    assert_eq(allocation_fee.value(), 200);

    // Test Recipient Percentages

    let (first_creation_recipient_addy, first_creation_recipient_bps) = creation_fee
        .recipients()[0]
        .recipient_data();

    assert_eq(first_creation_recipient_addy, INTEGRATOR);
    assert_eq(first_creation_recipient_bps.value(), 7_000);
    assert_eq(first_creation_recipient_bps.calc(10), 7);

    let (last_creation_recipient_addy, last_creation_recipient_bps) = creation_fee
        .recipients()[1]
        .recipient_data();

    assert_eq(last_creation_recipient_addy, INTEREST);
    assert_eq(last_creation_recipient_bps.value(), 3_000);
    assert_eq(last_creation_recipient_bps.calc(10), 3);

    let (first_swap_recipient_addy, first_swap_recipient_bps) = swap_fee
        .recipients()[0]
        .recipient_data();

    assert_eq(first_swap_recipient_addy, INTEGRATOR);
    assert_eq(first_swap_recipient_bps.value(), 5_000);
    assert_eq(first_swap_recipient_bps.calc(100), 50);

    let (second_swap_recipient_addy, second_swap_recipient_bps) = swap_fee
        .recipients()[1]
        .recipient_data();

    assert_eq(second_swap_recipient_addy, STAKE_HOLDER_1);
    assert_eq(second_swap_recipient_bps.value(), 2_500);
    assert_eq(second_swap_recipient_bps.calc(100), 25);
    
    let (third_swap_recipient_addy, third_swap_recipient_bps) = swap_fee
        .recipients()[2]
        .recipient_data();

    assert_eq(third_swap_recipient_addy, STAKE_HOLDER_2);
    assert_eq(third_swap_recipient_bps.value(), 2_500);
    assert_eq(third_swap_recipient_bps.calc(100), 25);

    let (first_migration_recipient_addy, first_migration_recipient_bps) = migration_fee
        .recipients()[0]
        .recipient_data();

    assert_eq(first_migration_recipient_addy, INTEGRATOR);
    assert_eq(first_migration_recipient_bps.value(), 4_000);
    assert_eq(first_migration_recipient_bps.calc(100), 40);

    let (second_migration_recipient_addy, second_migration_recipient_bps) = migration_fee
        .recipients()[1]
        .recipient_data();

    assert_eq(second_migration_recipient_addy, INTEREST);
    assert_eq(second_migration_recipient_bps.value(), 1_000);
    assert_eq(second_migration_recipient_bps.calc(100), 10);

    let (third_migration_recipient_addy, third_migration_recipient_bps) = migration_fee
        .recipients()[2]
        .recipient_data();

    assert_eq(third_migration_recipient_addy, STAKE_HOLDER_1);
    assert_eq(third_migration_recipient_bps.value(), 2_500);
    assert_eq(third_migration_recipient_bps.calc(100), 25);

    let (fourth_migration_recipient_addy, fourth_migration_recipient_bps) = migration_fee
        .recipients()[3]
        .recipient_data();

    assert_eq(fourth_migration_recipient_addy, STAKE_HOLDER_2);
    assert_eq(fourth_migration_recipient_bps.value(), 2_500);
    assert_eq(fourth_migration_recipient_bps.calc(100), 25);

    let (first_allocation_recipient_addy, first_allocation_recipient_bps) = allocation_fee
        .recipients()[0]
        .recipient_data();

    assert_eq(first_allocation_recipient_addy, INTEGRATOR);
    assert_eq(first_allocation_recipient_bps.value(), 3_000);

    assert_eq(first_allocation_recipient_bps.calc(100), 30);

    let (second_allocation_recipient_addy, second_allocation_recipient_bps) = allocation_fee
        .recipients()[1]
        .recipient_data();

    assert_eq(second_allocation_recipient_addy, STAKE_HOLDER_1);
    assert_eq(second_allocation_recipient_bps.value(), 3_500);
    assert_eq(second_allocation_recipient_bps.calc(100), 35);

    let (third_allocation_recipient_addy, third_allocation_recipient_bps) = allocation_fee
        .recipients()[2]
        .recipient_data();

    assert_eq(third_allocation_recipient_addy, STAKE_HOLDER_2);
    assert_eq(third_allocation_recipient_bps.value(), 3_500);
    assert_eq(third_allocation_recipient_bps.calc(100), 35);

    assert_eq(allocation_fee.vesting_period(), VESTING_PERIOD);
}

// #[test]
// fun test_take() {
//     let alice = @0x0;
//     let bob = @0x1;
//     let charlie = @0x2;
//     let jose = @0x3;

//     let fees = memez_fees::new(
//         vector[
//             vector[7_000, 3_000, 20],
//             vector[5_000, 2_000, 3_000, 300],
//             vector[2_500, 2_500, 2_500, 2_500, 60],
//         ],
//         vector[vector[alice, bob], vector[bob, alice], vector[charlie, jose, alice]],
//     );

//     let mut scenario = ts::begin(@0x9);

//     let mut asset = mint_for_testing<Meme>(1000, scenario.ctx());

//     fees.creation().take(&mut asset, scenario.ctx());

//     assert_eq(asset.burn_for_testing(), 980);

//     scenario.next_tx(@0x0);

//     let alice_creation_coin = scenario.take_from_address<Coin<Meme>>(alice);
//     let bob_creation_coin = scenario.take_from_address<Coin<Meme>>(bob);

//     assert_eq(alice_creation_coin.burn_for_testing(), 14);
//     assert_eq(bob_creation_coin.burn_for_testing(), 6);

//     let mut asset = mint_for_testing<Meme>(1000, scenario.ctx());

//     fees.swap(vector[@0x7]).take(&mut asset, scenario.ctx());

//     assert_eq(asset.burn_for_testing(), 970);

//     scenario.next_tx(@0x0);

//     let bob_swap_coin = scenario.take_from_address<Coin<Meme>>(bob);
//     let alice_swap_coin = scenario.take_from_address<Coin<Meme>>(alice);
//     let charlie_swap_coin = scenario.take_from_address<Coin<Meme>>(charlie);

//     assert_eq(bob_swap_coin.burn_for_testing(), 15);
//     assert_eq(alice_swap_coin.burn_for_testing(), 6);
//     assert_eq(charlie_swap_coin.burn_for_testing(), 9);

//     let mut asset = mint_for_testing<Meme>(1000, scenario.ctx());

//     fees.migration(vector[@0x7]).take(&mut asset, scenario.ctx());

//     assert_eq(asset.burn_for_testing(), 940);

//     scenario.next_tx(@0x0);

//     let bob_swap_coin = scenario.take_from_address<Coin<Meme>>(bob);
//     let alice_swap_coin = scenario.take_from_address<Coin<Meme>>(alice);
//     let charlie_swap_coin = scenario.take_from_address<Coin<Meme>>(charlie);
//     let jose_swap_coin = scenario.take_from_address<Coin<Meme>>(jose);

//     assert_eq(bob_swap_coin.burn_for_testing(), 15);
//     assert_eq(alice_swap_coin.burn_for_testing(), 15);
//     assert_eq(charlie_swap_coin.burn_for_testing(), 15);
//     assert_eq(jose_swap_coin.burn_for_testing(), 15);

//     let fees = memez_fees::new(
//         vector[
//             vector[7_000, 3_000, 0],
//             vector[5_000, 2_000, 3_000, 0],
//             vector[2_500, 2_500, 2_500, 2_500, 0],
//         ],
//         vector[vector[alice, bob], vector[bob, alice], vector[charlie, jose, alice]],
//     );

//     let mut asset = mint_for_testing<Meme>(1000, scenario.ctx());

//     fees.creation().take(&mut asset, scenario.ctx());
//     fees.swap(vector[@0x7]).take(&mut asset, scenario.ctx());
//     fees.migration(vector[@0x8]).take(&mut asset, scenario.ctx());

//     assert_eq(asset.burn_for_testing(), 1000);

//     scenario.end();
// }

// #[test, expected_failure(abort_code = memez_errors::EInvalidConfig, location = memez_fees)]
// fun test_new_invalid_config() {
//     memez_fees::new(
//         vector[vector[7_000, 3_000, 2], vector[5_000, 5_000, 30], vector[10_000, 0, 6]],
//         vector[vector[@0x0, @0x1], vector[@0x1]],
//     );
// }

// #[test, expected_failure(abort_code = memez_errors::EInvalidPercentages, location = memez_utils)]
// fun test_new_invalid_creation_percentages() {
//     memez_fees::new(
//         vector[vector[7_000, 3_000 - 1, 2], vector[5_000, 5_000, 30], vector[10_000, 0, 6]],
//         vector[vector[@0x0, @0x1], vector[@0x1], vector[@0x2]],
//     );
// }

// #[test, expected_failure(abort_code = memez_errors::EInvalidPercentages, location = memez_utils)]
// fun test_new_invalid_swap_percentages() {
//     memez_fees::new(
//         vector[vector[7_000, 3_000, 2], vector[5_000 - 1, 5_000, 30], vector[10_000, 0, 6]],
//         vector[vector[@0x0, @0x1], vector[@0x1], vector[@0x2]],
//     );
// }

// #[test, expected_failure(abort_code = memez_errors::EInvalidPercentages, location = memez_utils)]
// fun test_new_invalid_migration_percentages() {
//     memez_fees::new(
//         vector[vector[7_000, 3_000, 2], vector[5_000, 5_000, 30], vector[10_000, 1, 6]],
//         vector[vector[@0x0, @0x1], vector[@0x1], vector[@0x2]],
//     );
// }

// #[test, expected_failure(abort_code = memez_errors::EWrongRecipientsLength, location = memez_fees)]
// fun test_new_wrong_creation_recipients() {
//     memez_fees::new(
//         vector[vector[7_000, 3_000, 2], vector[5_000, 5_000, 0, 30], vector[10_000, 0, 6]],
//         vector[vector[@0x0], vector[@0x1], vector[@0x2]],
//     );
// }

// #[test, expected_failure(abort_code = memez_errors::EWrongRecipientsLength, location = memez_fees)]
// fun test_new_wrong_swap_recipients() {
//     memez_fees::new(
//         vector[vector[7_000, 3_000, 2], vector[5_000, 5_000, 0, 30], vector[10_000, 0, 6]],
//         vector[vector[@0x0, @0x1], vector[@0x1], vector[@0x2]],
//     );
// }

// #[test, expected_failure(abort_code = memez_errors::EWrongRecipientsLength, location = memez_fees)]
// fun test_new_wrong_migration_recipients() {
//     memez_fees::new(
//         vector[vector[7_000, 3_000, 2], vector[5_000, 5_000, 30], vector[10_000, 0, 0, 6]],
//         vector[vector[@0x0, @0x1], vector[@0x1], vector[@0x2]],
//     );
// }

fun default_fees(): MemezFees {
    let fees = memez_fees::new(
        vector[
            vector[7_000, 3_000, 2 * POW_9],
            vector[5_000, 2_500, 2_500, 100],
            vector[4_000, 1_000, 2_500, 2_500, 200 * POW_9],
            vector[3_000, 3_500, 3_500, 200],
        ],
        vector[
            vector[INTEGRATOR, INTEREST],
            vector[INTEGRATOR],
            vector[INTEGRATOR, INTEREST],
            vector[INTEGRATOR],
        ],
    );

    fees
}
