// #[test_only]
// module memez_fun::memez_fees_tests;

// use memez_fun::{memez_errors, memez_fees::{Self, MemezFees}, memez_test_helpers, memez_utils};
// use memez_vesting::memez_vesting::MemezVesting;
// use sui::{
//     clock,
//     coin::{mint_for_testing, Coin},
//     test_scenario as ts,
//     test_utils::{assert_eq, destroy}
// };

// use fun memez_test_helpers::do as vector.do;

// const POW_9: u64 = 1_000_000_000;

// const INTEREST: address = @0x5;

// const INTEGRATOR: address = @0x6;

// const STAKE_HOLDER_1: address = @0x7;

// const STAKE_HOLDER_2: address = @0x8;

// const VESTING_PERIOD: u64 = 101;

// public struct Meme()

// #[test]
// fun test_new() {
//     let payloads = default_fees().payloads();

//     assert_eq(payloads[0].payload_value(), 2 * POW_9);
//     assert_eq(payloads[1].payload_value(), 100);
//     assert_eq(payloads[2].payload_value(), 200 * POW_9);
//     assert_eq(payloads[3].payload_value(), 200);

//     assert_eq(payloads[0].payload_percentages(), vector[7_000, 3_000]);
//     assert_eq(payloads[1].payload_percentages(), vector[5_000, 2_500, 2_500]);
//     assert_eq(payloads[2].payload_percentages(), vector[4_000, 1_000, 2_500, 2_500]);
//     assert_eq(payloads[3].payload_percentages(), vector[3_000, 3_500, 3_500]);

//     assert_eq(payloads[0].payload_recipients(), vector[INTEGRATOR, INTEREST]);
//     assert_eq(payloads[1].payload_recipients(), vector[INTEGRATOR]);
//     assert_eq(payloads[2].payload_recipients(), vector[INTEGRATOR, INTEREST]);
//     assert_eq(payloads[3].payload_recipients(), vector[INTEGRATOR]);
// }

// #[test]
// fun test_calculate() {
//     let fees = default_fees();

//     let creation_fee = fees.creation();
//     let swap_fee = fees.swap(vector[STAKE_HOLDER_1, STAKE_HOLDER_2]);
//     let migration_fee = fees.migration(vector[STAKE_HOLDER_1, STAKE_HOLDER_2]);
//     let allocation_fee = fees.allocation(vector[STAKE_HOLDER_1, STAKE_HOLDER_2], VESTING_PERIOD);

//     assert_eq(creation_fee.recipients().length(), 2);
//     assert_eq(swap_fee.recipients().length(), 3);
//     assert_eq(migration_fee.recipients().length(), 4);
//     assert_eq(allocation_fee.recipients().length(), 3);

//     // Test Values

//     assert_eq(creation_fee.value(), 2 * POW_9);
//     assert_eq(swap_fee.value(), 100);
//     assert_eq(migration_fee.value(), 200 * POW_9);
//     assert_eq(allocation_fee.value(), 200);

//     // Test Recipient Percentages

//     let expected_creation_recipients = vector[INTEGRATOR, INTEREST];
//     let expected_creation_percentages = vector[7_000, 3_000];
//     let expected_creation_values = vector[2 * POW_9 * 7_000 / 10_000, 2 * POW_9 * 3_000 / 10_000];

//     creation_fee.recipients().do!(|recipient, i| {
//         let (recipient_addy, recipient_bps) = recipient.recipient_data();

//         assert_eq(recipient_addy, expected_creation_recipients[i]);
//         assert_eq(recipient_bps.value(), expected_creation_percentages[i]);
//         assert_eq(recipient_bps.calc(2 * POW_9), expected_creation_values[i]);
//     });

//     let expected_swap_recipients = vector[INTEGRATOR, STAKE_HOLDER_1, STAKE_HOLDER_2];
//     let expected_swap_percentages = vector[5_000, 2_500, 2_500];
//     let expected_swap_values = vector[
//         100 * 5_000 / 10_000,
//         100 * 2_500 / 10_000,
//         100 * 2_500 / 10_000,
//     ];

//     swap_fee.recipients().do!(|recipient, i| {
//         let (recipient_addy, recipient_bps) = recipient.recipient_data();

//         assert_eq(recipient_addy, expected_swap_recipients[i]);
//         assert_eq(recipient_bps.value(), expected_swap_percentages[i]);
//         assert_eq(recipient_bps.calc(100), expected_swap_values[i]);
//     });

//     let expected_migration_recipients = vector[
//         INTEGRATOR,
//         INTEREST,
//         STAKE_HOLDER_1,
//         STAKE_HOLDER_2,
//     ];
//     let expected_migration_percentages = vector[4_000, 1_000, 2_500, 2_500];
//     let expected_migration_values = vector[
//         200 * POW_9 * 4_000 / 10_000,
//         200 * POW_9 * 1_000 / 10_000,
//         200 * POW_9 * 2_500 / 10_000,
//         200 * POW_9 * 2_500 / 10_000,
//     ];

//     migration_fee.recipients().do!(|recipient, i| {
//         let (recipient_addy, recipient_bps) = recipient.recipient_data();

//         assert_eq(recipient_addy, expected_migration_recipients[i]);
//         assert_eq(recipient_bps.value(), expected_migration_percentages[i]);
//         assert_eq(recipient_bps.calc(200 * POW_9), expected_migration_values[i]);
//     });

//     let expected_allocation_recipients = vector[INTEGRATOR, STAKE_HOLDER_1, STAKE_HOLDER_2];
//     let expected_allocation_percentages = vector[3_000, 3_500, 3_500];
//     let expected_allocation_values = vector[
//         100 * 3_000 / 10_000,
//         100 * 3_500 / 10_000,
//         100 * 3_500 / 10_000,
//     ];

//     allocation_fee.recipients().do!(|recipient, i| {
//         let (recipient_addy, recipient_bps) = recipient.recipient_data();

//         assert_eq(recipient_addy, expected_allocation_recipients[i]);
//         assert_eq(recipient_bps.value(), expected_allocation_percentages[i]);
//         assert_eq(recipient_bps.calc(100), expected_allocation_values[i]);
//     });

//     assert_eq(allocation_fee.vesting_period(), VESTING_PERIOD);
// }

// #[test]
// fun test_take() {
//     let fees = default_fees();

//     let mut scenario = ts::begin(@0x9);

//     let mut asset = mint_for_testing<Meme>(5 * POW_9, scenario.ctx());

//     fees.creation().take(&mut asset, scenario.ctx());

//     assert_eq(asset.burn_for_testing(), 3 * POW_9);

//     scenario.next_tx(@0x0);

//     let integrator_creation_coin = scenario.take_from_address<Coin<Meme>>(INTEGRATOR);
//     let interest_creation_coin = scenario.take_from_address<Coin<Meme>>(INTEREST);

//     assert_eq(integrator_creation_coin.burn_for_testing(), 2 * POW_9 * 7_000 / 10_000);
//     assert_eq(interest_creation_coin.burn_for_testing(), 2 * POW_9 * 3_000 / 10_000);

//     let mut asset = mint_for_testing<Meme>(10_000, scenario.ctx());

//     fees.swap(vector[STAKE_HOLDER_1, STAKE_HOLDER_2]).take(&mut asset, scenario.ctx());

//     assert_eq(asset.burn_for_testing(), 9_900);

//     scenario.next_tx(@0x0);

//     let integrator_swap_coin = scenario.take_from_address<Coin<Meme>>(INTEGRATOR);
//     let stake_holder_1_swap_coin = scenario.take_from_address<Coin<Meme>>(STAKE_HOLDER_1);
//     let stake_holder_2_swap_coin = scenario.take_from_address<Coin<Meme>>(STAKE_HOLDER_2);

//     assert_eq(integrator_swap_coin.burn_for_testing(), 100 * 5_000 / 10_000);
//     assert_eq(stake_holder_1_swap_coin.burn_for_testing(), 100 * 2_500 / 10_000);
//     assert_eq(stake_holder_2_swap_coin.burn_for_testing(), 100 * 2_500 / 10_000);

//     let mut asset = mint_for_testing<Meme>(200 * POW_9, scenario.ctx());

//     fees.migration(vector[STAKE_HOLDER_1, STAKE_HOLDER_2]).take(&mut asset, scenario.ctx());

//     assert_eq(asset.burn_for_testing(), 0);

//     scenario.next_tx(@0x0);

//     let integrator_migration_coin = scenario.take_from_address<Coin<Meme>>(INTEGRATOR);
//     let interest_migration_coin = scenario.take_from_address<Coin<Meme>>(INTEREST);
//     let stake_holder_1_migration_coin = scenario.take_from_address<Coin<Meme>>(STAKE_HOLDER_1);
//     let stake_holder_2_migration_coin = scenario.take_from_address<Coin<Meme>>(STAKE_HOLDER_2);

//     assert_eq(integrator_migration_coin.burn_for_testing(), 200 * POW_9 * 4_000 / 10_000);
//     assert_eq(interest_migration_coin.burn_for_testing(), 200 * POW_9 * 1_000 / 10_000);
//     assert_eq(stake_holder_1_migration_coin.burn_for_testing(), 200 * POW_9 * 2_500 / 10_000);
//     assert_eq(stake_holder_2_migration_coin.burn_for_testing(), 200 * POW_9 * 2_500 / 10_000);

//     scenario.next_tx(@0x0);

//     let mut asset = mint_for_testing<Meme>(2_000 * POW_9, scenario.ctx()).into_balance();

//     let clock = clock::create_for_testing(scenario.ctx());

//     fees
//         .allocation(vector[STAKE_HOLDER_1, STAKE_HOLDER_2], 101)
//         .take_allocation(
//             &mut asset,
//             &clock,
//             scenario.ctx(),
//         );

//     assert_eq(asset.value(), (2000 - 40) * POW_9);

//     destroy(asset);

//     scenario.next_tx(@0x0);

//     let integrator_allocation_vesting = scenario.take_from_address<MemezVesting<Meme>>(INTEGRATOR);
//     let stake_holder_1_allocation_vesting = scenario.take_from_address<MemezVesting<Meme>>(
//         STAKE_HOLDER_1,
//     );
//     let stake_holder_2_allocation_vesting = scenario.take_from_address<MemezVesting<Meme>>(
//         STAKE_HOLDER_2,
//     );

//     assert_eq(integrator_allocation_vesting.duration(), 101);
//     assert_eq(stake_holder_1_allocation_vesting.duration(), 101);
//     assert_eq(stake_holder_2_allocation_vesting.duration(), 101);

//     assert_eq(integrator_allocation_vesting.balance(), 40 * POW_9 * 3_000 / 10_000);
//     assert_eq(stake_holder_1_allocation_vesting.balance(), 40 * POW_9 * 3_500 / 10_000);
//     assert_eq(stake_holder_2_allocation_vesting.balance(), 40 * POW_9 * 3_500 / 10_000);

//     destroy(integrator_allocation_vesting);
//     destroy(stake_holder_1_allocation_vesting);
//     destroy(stake_holder_2_allocation_vesting);

//     let fees = memez_fees::new(
//         vector[
//             vector[7_000, 3_000, 0],
//             vector[5_000, 2_000, 3_000, 0],
//             vector[2_500, 2_500, 2_500, 2_500, 0],
//             vector[5_000, 5_000, 0],
//         ],
//         vector[
//             vector[INTEGRATOR, INTEREST],
//             vector[INTEGRATOR, STAKE_HOLDER_1, STAKE_HOLDER_2],
//             vector[INTEGRATOR, INTEREST, STAKE_HOLDER_1, STAKE_HOLDER_2],
//             vector[STAKE_HOLDER_1, STAKE_HOLDER_2],
//         ],
//     );

//     let mut asset = mint_for_testing<Meme>(1000, scenario.ctx());

//     fees.creation().take(&mut asset, scenario.ctx());
//     fees.swap(vector[]).take(&mut asset, scenario.ctx());
//     fees.migration(vector[]).take(&mut asset, scenario.ctx());

//     let mut asset = asset.into_balance();

//     fees.allocation(vector[], 101).take_allocation(&mut asset, &clock, scenario.ctx());

//     assert_eq(asset.value(), 1000);

//     destroy(asset);
//     destroy(clock);

//     scenario.end();
// }

// #[test, expected_failure(abort_code = memez_errors::EInvalidConfig, location = memez_fees)]
// fun test_new_invalid_config() {
//     memez_fees::new(
//         vector[
//             vector[7_000, 3_000, 2],
//             vector[5_000, 5_000, 30],
//             vector[10_000, 0, 6],
//             vector[10_000, 0, 6],
//         ],
//         vector[vector[@0x0, @0x1], vector[@0x1], vector[@0x2]],
//     );
// }

// #[test, expected_failure(abort_code = memez_errors::EInvalidPercentages, location = memez_utils)]
// fun test_new_invalid_creation_percentages() {
//     memez_fees::new(
//         vector[
//             vector[7_000, 3_000 - 1, 2],
//             vector[5_000, 5_000, 30],
//             vector[10_000, 0, 6],
//             vector[10_000, 0, 6],
//         ],
//         vector[vector[@0x0, @0x1], vector[@0x1], vector[@0x2], vector[@0x3]],
//     );
// }

// #[test, expected_failure(abort_code = memez_errors::EInvalidPercentages, location = memez_utils)]
// fun test_new_invalid_swap_percentages() {
//     memez_fees::new(
//         vector[
//             vector[7_000, 3_000, 2],
//             vector[5_000 - 1, 5_000, 30],
//             vector[10_000, 0, 6],
//             vector[10_000, 0, 6],
//         ],
//         vector[vector[@0x0, @0x1], vector[@0x1], vector[@0x2], vector[@0x3]],
//     );
// }

// #[test, expected_failure(abort_code = memez_errors::EInvalidPercentages, location = memez_utils)]
// fun test_new_invalid_migration_percentages() {
//     memez_fees::new(
//         vector[
//             vector[7_000, 3_000, 2],
//             vector[5_000, 5_000, 30],
//             vector[10_000, 1, 6],
//             vector[10_000, 0, 6],
//         ],
//         vector[vector[@0x0, @0x1], vector[@0x1], vector[@0x2], vector[@0x3]],
//     );
// }

// #[test, expected_failure(abort_code = memez_errors::EInvalidPercentages, location = memez_utils)]
// fun test_new_invalid_allocation_percentages() {
//     memez_fees::new(
//         vector[
//             vector[7_000, 3_000, 2],
//             vector[5_000, 5_000, 30],
//             vector[10_000, 0, 6],
//             vector[10_000, 1, 6],
//         ],
//         vector[vector[@0x0, @0x1], vector[@0x1], vector[@0x2], vector[@0x3]],
//     );
// }

// #[
//     test,
//     expected_failure(
//         abort_code = memez_errors::EInvalidCreationFeeConfig,
//         location = memez_fees,
//     ),
// ]
// fun test_new_wrong_creation_recipients() {
//     memez_fees::new(
//         vector[
//             vector[7_000, 3_000, 2],
//             vector[5_000, 5_000, 0, 30],
//             vector[10_000, 0, 6],
//             vector[10_000, 0, 6],
//         ],
//         vector[vector[@0x0], vector[@0x1], vector[@0x2], vector[@0x3]],
//     );
// }

// fun default_fees(): MemezFees {
//     let fees = memez_fees::new(
//         vector[
//             vector[7_000, 3_000, 2 * POW_9],
//             vector[5_000, 2_500, 2_500, 100],
//             vector[4_000, 1_000, 2_500, 2_500, 200 * POW_9],
//             vector[3_000, 3_500, 3_500, 200],
//         ],
//         vector[
//             vector[INTEGRATOR, INTEREST],
//             vector[INTEGRATOR],
//             vector[INTEGRATOR, INTEREST],
//             vector[INTEGRATOR],
//         ],
//     );

//     fees
// }
