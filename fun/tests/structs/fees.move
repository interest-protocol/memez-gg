#[test_only]
module memez_fun::memez_fees_tests;

use interest_bps::bps;
use memez_fun::{memez_errors, memez_fees::{Self, MemezFees}, memez_test_helpers};
use memez_vesting::memez_vesting::MemezVesting;
use sui::{
    clock,
    coin::{mint_for_testing, Coin},
    test_scenario as ts,
    test_utils::{assert_eq, destroy}
};

use fun memez_test_helpers::do as vector.do;

const POW_9: u64 = 1_000_000_000;

const INTEREST: address = @0x5;

const INTEGRATOR: address = @0x6;

const STAKE_HOLDER_1: address = @0x7;

const STAKE_HOLDER_2: address = @0x8;

const VESTING_PERIODS: vector<u64> = vector[100, 101, 102];

const TEN_PERCENT: u64 = 1_000;

public struct Meme()

#[test]
fun test_new() {
    let payloads = default_fees().payloads();

    assert_eq(payloads[0].payload_value(), 2 * POW_9);
    assert_eq(payloads[1].payload_value(), 200);
    assert_eq(payloads[2].payload_value(), 100);
    assert_eq(payloads[3].payload_value(), TEN_PERCENT);
    assert_eq(payloads[4].payload_value(), 2000);

    assert_eq(payloads[0].payload_percentages(), vector[7_000, 3_000]);
    assert_eq(payloads[1].payload_percentages(), vector[5_000, 2_500, 2_500]);
    assert_eq(payloads[2].payload_percentages(), vector[2_500, 2_500, 5_000]);
    assert_eq(payloads[3].payload_percentages(), vector[4_000, 1_000, 2_500, 2_500]);
    assert_eq(payloads[4].payload_percentages(), vector[3_000, 3_500, 3_500]);

    assert_eq(payloads[0].payload_recipients(), vector[INTEGRATOR, INTEREST]);
    assert_eq(payloads[1].payload_recipients(), vector[INTEGRATOR]);
    assert_eq(payloads[2].payload_recipients(), vector[INTEGRATOR]);
    assert_eq(payloads[3].payload_recipients(), vector[INTEGRATOR, INTEREST]);
    assert_eq(payloads[4].payload_recipients(), vector[INTEGRATOR]);

    assert_eq(default_fees().dynamic_stake_holders(), 2);
    assert_eq(default_fees().vesting_periods(), VESTING_PERIODS);
}

#[test]
fun test_calculate() {
    let fees = default_fees();

    let mut ctx = tx_context::dummy();

    let mut allocation_balance = mint_for_testing<Meme>(1000, &mut ctx).into_balance();

    let creation_fee = fees.creation();
    let quote_swap_fee = fees.quote_swap(vector[STAKE_HOLDER_1, STAKE_HOLDER_2]);
    let meme_swap_fee = fees.meme_swap(vector[STAKE_HOLDER_1, STAKE_HOLDER_2]);

    let migration_fee = fees.migration(vector[STAKE_HOLDER_1, STAKE_HOLDER_2]);
    let allocation_fee = fees.allocation(
        &mut allocation_balance,
        vector[STAKE_HOLDER_1, STAKE_HOLDER_2],
    );

    let creation_fee_recipients = creation_fee.distributor().recipient_addresses();
    let quote_swap_fee_recipients = quote_swap_fee.distributor().recipient_addresses();
    let meme_swap_fee_recipients = meme_swap_fee.distributor().recipient_addresses();
    let migration_fee_recipients = migration_fee.distributor().recipient_addresses();
    let allocation_fee_recipients = allocation_fee.distributor().recipient_addresses();

    assert_eq(creation_fee_recipients.length(), 2);
    assert_eq(quote_swap_fee_recipients.length(), 3);
    assert_eq(meme_swap_fee_recipients.length(), 3);
    assert_eq(migration_fee_recipients.length(), 4);
    assert_eq(allocation_fee_recipients.length(), 3);

    // Test Values

    assert_eq(creation_fee.value(), 2 * POW_9);
    assert_eq(quote_swap_fee.value(), 100);
    assert_eq(meme_swap_fee.value(), 200);
    assert_eq(migration_fee.value(), TEN_PERCENT);
    assert_eq(allocation_fee.value(), 200);

    // Test Recipient Percentages

    let expected_creation_recipients = vector[INTEGRATOR, INTEREST];
    let expected_creation_percentages = vector[7_000, 3_000];
    let expected_creation_values = vector[2 * POW_9 * 7_000 / 10_000, 2 * POW_9 * 3_000 / 10_000];

    let creation_fee_values = creation_fee.distributor().recipient_percentages();
    let quote_swap_fee_values = quote_swap_fee.distributor().recipient_percentages();
    let meme_swap_fee_values = meme_swap_fee.distributor().recipient_percentages();
    let migration_fee_values = migration_fee.distributor().recipient_percentages();
    let allocation_fee_values = allocation_fee.distributor().recipient_percentages();

    creation_fee_recipients.do!(|recipient_address, i| {
        let recipient_bps = creation_fee_values[i];

        assert_eq(recipient_address, expected_creation_recipients[i]);
        assert_eq(recipient_bps.value(), expected_creation_percentages[i]);
        assert_eq(recipient_bps.calc(2 * POW_9), expected_creation_values[i]);
    });

    let expected_quote_swap_recipients = vector[INTEGRATOR, STAKE_HOLDER_1, STAKE_HOLDER_2];
    let expected_quote_swap_percentages = vector[2_500, 2_500, 5_000];
    let expected_quote_swap_values = vector[
        100 * 2_500 / 10_000,
        100 * 2_500 / 10_000,
        100 * 5_000 / 10_000,
    ];

    quote_swap_fee_recipients.do!(|recipient_address, i| {
        let recipient_bps = quote_swap_fee_values[i];

        assert_eq(recipient_address, expected_quote_swap_recipients[i]);
        assert_eq(recipient_bps.value(), expected_quote_swap_percentages[i]);
        assert_eq(recipient_bps.calc(100), expected_quote_swap_values[i]);
    });

    let expected_meme_swap_recipients = vector[INTEGRATOR, STAKE_HOLDER_1, STAKE_HOLDER_2];
    let expected_meme_swap_percentages = vector[5_000, 2_500, 2_500];
    let expected_meme_swap_values = vector[
        200 * 5_000 / 10_000,
        200 * 2_500 / 10_000,
        200 * 2_500 / 10_000,
    ];

    meme_swap_fee_recipients.do!(|recipient_address, i| {
        let recipient_bps = meme_swap_fee_values[i];

        assert_eq(recipient_address, expected_meme_swap_recipients[i]);
        assert_eq(recipient_bps.value(), expected_meme_swap_percentages[i]);
        assert_eq(recipient_bps.calc(200), expected_meme_swap_values[i]);
    });

    let expected_migration_recipients = vector[
        INTEGRATOR,
        INTEREST,
        STAKE_HOLDER_1,
        STAKE_HOLDER_2,
    ];
    let expected_migration_percentages = vector[4_000, 1_000, 2_500, 2_500];
    let expected_migration_values = vector[
        TEN_PERCENT * 4_000 / 10_000,
        TEN_PERCENT * 1_000 / 10_000,
        TEN_PERCENT * 2_500 / 10_000,
        TEN_PERCENT * 2_500 / 10_000,
    ];

    migration_fee_recipients.do!(|recipient_address, i| {
        let recipient_bps = migration_fee_values[i];

        assert_eq(recipient_address, expected_migration_recipients[i]);
        assert_eq(recipient_bps.value(), expected_migration_percentages[i]);
        assert_eq(recipient_bps.calc(TEN_PERCENT), expected_migration_values[i]);
    });

    let expected_allocation_recipients = vector[INTEGRATOR, STAKE_HOLDER_1, STAKE_HOLDER_2];
    let expected_allocation_percentages = vector[3_000, 3_500, 3_500];
    let expected_allocation_values = vector[
        100 * 3_000 / 10_000,
        100 * 3_500 / 10_000,
        100 * 3_500 / 10_000,
    ];

    allocation_fee_recipients.do!(|recipient_address, i| {
        let recipient_bps = allocation_fee_values[i];

        assert_eq(recipient_address, expected_allocation_recipients[i]);
        assert_eq(recipient_bps.value(), expected_allocation_percentages[i]);
        assert_eq(recipient_bps.calc(100), expected_allocation_values[i]);
    });

    assert_eq(allocation_fee.vesting_periods(), VESTING_PERIODS);

    destroy(allocation_fee);
    destroy(allocation_balance);
}

#[test]
fun test_take() {
    let fees = default_fees();

    let mut scenario = ts::begin(@0x9);

    let mut asset = mint_for_testing<Meme>(5 * POW_9, scenario.ctx());

    fees.creation().take(&mut asset, scenario.ctx());

    assert_eq(asset.burn_for_testing(), 3 * POW_9);

    scenario.next_tx(@0x0);

    let integrator_creation_coin = scenario.take_from_address<Coin<Meme>>(INTEGRATOR);
    let interest_creation_coin = scenario.take_from_address<Coin<Meme>>(INTEREST);

    assert_eq(integrator_creation_coin.burn_for_testing(), 2 * POW_9 * 7_000 / 10_000);
    assert_eq(interest_creation_coin.burn_for_testing(), 2 * POW_9 * 3_000 / 10_000);

    let mut asset = mint_for_testing<Meme>(10_000, scenario.ctx());

    fees.meme_swap(vector[STAKE_HOLDER_1, STAKE_HOLDER_2]).take(&mut asset, scenario.ctx());

    assert_eq(asset.burn_for_testing(), 9_800);

    scenario.next_tx(@0x0);

    let integrator_swap_coin = scenario.take_from_address<Coin<Meme>>(INTEGRATOR);
    let stake_holder_1_swap_coin = scenario.take_from_address<Coin<Meme>>(STAKE_HOLDER_1);
    let stake_holder_2_swap_coin = scenario.take_from_address<Coin<Meme>>(STAKE_HOLDER_2);

    assert_eq(integrator_swap_coin.burn_for_testing(), 200 * 5_000 / 10_000);
    assert_eq(stake_holder_1_swap_coin.burn_for_testing(), 200 * 2_500 / 10_000);
    assert_eq(stake_holder_2_swap_coin.burn_for_testing(), 200 * 2_500 / 10_000);

    let mut asset = mint_for_testing<Meme>(10_000, scenario.ctx());

    fees.quote_swap(vector[STAKE_HOLDER_1, STAKE_HOLDER_2]).take(&mut asset, scenario.ctx());

    assert_eq(asset.burn_for_testing(), 9_900);

    scenario.next_tx(@0x0);

    let integrator_swap_coin = scenario.take_from_address<Coin<Meme>>(INTEGRATOR);
    let stake_holder_1_swap_coin = scenario.take_from_address<Coin<Meme>>(STAKE_HOLDER_1);
    let stake_holder_2_swap_coin = scenario.take_from_address<Coin<Meme>>(STAKE_HOLDER_2);

    assert_eq(integrator_swap_coin.burn_for_testing(), 100 * 2_500 / 10_000);
    assert_eq(stake_holder_1_swap_coin.burn_for_testing(), 100 * 2_500 / 10_000);
    assert_eq(stake_holder_2_swap_coin.burn_for_testing(), 100 * 5_000 / 10_000);

    let mut asset = mint_for_testing<Meme>(200 * POW_9, scenario.ctx());

    fees.migration(vector[STAKE_HOLDER_1, STAKE_HOLDER_2]).take(&mut asset, scenario.ctx());

    // Takes 10% of 200 * POW_9
    assert_eq(asset.burn_for_testing(), 180 * POW_9);

    scenario.next_tx(@0x0);

    let integrator_migration_coin = scenario.take_from_address<Coin<Meme>>(INTEGRATOR);
    let interest_migration_coin = scenario.take_from_address<Coin<Meme>>(INTEREST);
    let stake_holder_1_migration_coin = scenario.take_from_address<Coin<Meme>>(STAKE_HOLDER_1);
    let stake_holder_2_migration_coin = scenario.take_from_address<Coin<Meme>>(STAKE_HOLDER_2);

    assert_eq(integrator_migration_coin.burn_for_testing(), 20 * POW_9 * 4_000 / 10_000);
    assert_eq(interest_migration_coin.burn_for_testing(), 20 * POW_9 * 1_000 / 10_000);
    assert_eq(stake_holder_1_migration_coin.burn_for_testing(), 20 * POW_9 * 2_500 / 10_000);
    assert_eq(stake_holder_2_migration_coin.burn_for_testing(), 20 * POW_9 * 2_500 / 10_000);

    scenario.next_tx(@0x0);

    let mut allocation_balance = mint_for_testing<Meme>(200 * POW_9, scenario.ctx()).into_balance();

    let mut clock = clock::create_for_testing(scenario.ctx());

    clock.increment_for_testing(60_000);

    let mut allocation_fee = fees.allocation(
        &mut allocation_balance,
        vector[STAKE_HOLDER_1, STAKE_HOLDER_2],
    );

    allocation_fee.take(&clock, scenario.ctx());

    destroy(allocation_fee);

    destroy(allocation_balance);

    scenario.next_tx(@0x0);

    let integrator_allocation_vesting = scenario.take_from_address<MemezVesting<Meme>>(INTEGRATOR);

    let stake_holder_1_allocation_vesting = scenario.take_from_address<MemezVesting<Meme>>(
        STAKE_HOLDER_1,
    );
    let stake_holder_2_allocation_vesting = scenario.take_from_address<MemezVesting<Meme>>(
        STAKE_HOLDER_2,
    );

    let vesting_period = VESTING_PERIODS;

    assert_eq(integrator_allocation_vesting.duration(), vesting_period[0]);
    assert_eq(stake_holder_1_allocation_vesting.duration(), vesting_period[1]);
    assert_eq(stake_holder_2_allocation_vesting.duration(), vesting_period[2]);

    assert_eq(integrator_allocation_vesting.balance(), 40 * POW_9 * 3_000 / 10_000);
    assert_eq(stake_holder_1_allocation_vesting.balance(), 40 * POW_9 * 3_500 / 10_000);
    assert_eq(stake_holder_2_allocation_vesting.balance(), 40 * POW_9 * 3_500 / 10_000);

    destroy(integrator_allocation_vesting);
    destroy(stake_holder_1_allocation_vesting);
    destroy(stake_holder_2_allocation_vesting);

    let fees = memez_fees::new(
        vector[
            vector[7_000, 3_000, 0],
            vector[5_000, 2_000, 3_000, 0],
            vector[5_000, 2_000, 3_000, 0],
            vector[2_500, 2_500, 2_500, 2_500, 0],
            vector[5_000, 5_000, 0],
            vector[100, 101],
        ],
        vector[
            vector[INTEGRATOR, INTEREST],
            vector[INTEGRATOR, STAKE_HOLDER_1, STAKE_HOLDER_2],
            vector[INTEGRATOR, INTEREST, STAKE_HOLDER_1, STAKE_HOLDER_2],
            vector[STAKE_HOLDER_1, STAKE_HOLDER_2],
        ],
    );

    let mut asset = mint_for_testing<Meme>(1000, scenario.ctx());

    fees.creation().take(&mut asset, scenario.ctx());
    fees.quote_swap(vector[]).take(&mut asset, scenario.ctx());
    fees.meme_swap(vector[]).take(&mut asset, scenario.ctx());
    fees.migration(vector[]).take(&mut asset, scenario.ctx());

    let mut allocation_balance = mint_for_testing<Meme>(200 * POW_9, scenario.ctx()).into_balance();

    let mut allocation_fee = fees.allocation(&mut allocation_balance, vector[]);

    allocation_fee.take(&clock, scenario.ctx());

    assert_eq(asset.burn_for_testing(), 1000);
    assert_eq(allocation_balance.value(), 200 * POW_9);

    destroy(allocation_fee);
    destroy(allocation_balance);

    destroy(clock);

    scenario.end();
}

#[test]
fun test_calculate_with_discount() {
    let fees = default_fees();

    let quote_swap_fee = fees.quote_swap(vector[STAKE_HOLDER_1, STAKE_HOLDER_2]);

    // 1% fee
    assert_eq(quote_swap_fee.calculate(10_000), 100);

    // 1% fee with 10% discount
    assert_eq(quote_swap_fee.calculate_with_discount(bps::new(10), 10_000), 90);

    let creation_fee = fees.creation();

    // Nominal fees ignores amount_in
    assert_eq(creation_fee.calculate(10_000), 2 * POW_9);

    // No discount on nominal values
    assert_eq(creation_fee.calculate_with_discount(bps::new(10), 10_000), 2 * POW_9);
}

#[test]
fun test_take_with_discount() {
    let fees = default_fees();

    let ctx = &mut tx_context::dummy();

    let quote_swap_fee = fees.quote_swap(vector[STAKE_HOLDER_1, STAKE_HOLDER_2]);

    let mut meme_coin = mint_for_testing<Meme>(10_000, ctx);

    assert_eq(quote_swap_fee.take(&mut meme_coin, ctx), 100);

    assert_eq(meme_coin.value(), 9_900);

    assert_eq(quote_swap_fee.take_with_discount(&mut meme_coin, bps::new(10), ctx), 90);

    assert_eq(meme_coin.burn_for_testing(), 9_810);
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EInvalidDynamicStakeHolders,
        location = memez_fees,
    ),
]
fun test_assert_dynamic_stake_holders() {
    default_fees().assert_dynamic_stake_holders(vector[@0x0, @0x1, @0x2]);
}

#[test, expected_failure(abort_code = memez_errors::EInvalidConfig, location = memez_fees)]
fun test_new_invalid_config() {
    memez_fees::new(
        vector[
            vector[7_000, 3_000, 2],
            vector[5_000, 5_000, 30],
            vector[10_000, 0, 6],
            vector[10_000, 0, 6],
            VESTING_PERIODS,
        ],
        vector[vector[@0x0, @0x1], vector[@0x1], vector[@0x2]],
    );
}

#[test, expected_failure(abort_code = memez_errors::EInvalidPercentages, location = memez_fees)]
fun test_new_invalid_creation_percentages() {
    memez_fees::new(
        vector[
            vector[7_000, 3_000 - 1, 2],
            vector[5_000, 5_000, 30],
            vector[5_000, 5_000, 30],
            vector[10_000, 0, 6],
            vector[10_000, 0, 6],
            VESTING_PERIODS,
        ],
        vector[vector[@0x0, @0x1], vector[@0x1], vector[@0x2], vector[@0x3]],
    );
}

#[test, expected_failure(abort_code = memez_errors::EInvalidPercentages, location = memez_fees)]
fun test_new_invalid_swap_percentages() {
    memez_fees::new(
        vector[
            vector[7_000, 3_000, 2],
            vector[5_000 - 1, 5_000, 30],
            vector[5_000, 5_000, 30],
            vector[10_000, 0, 6],
            vector[10_000, 0, 6],
            VESTING_PERIODS,
        ],
        vector[vector[@0x0, @0x1], vector[@0x1], vector[@0x2], vector[@0x3]],
    );
}

#[test, expected_failure(abort_code = memez_errors::EInvalidPercentages, location = memez_fees)]
fun test_new_invalid_migration_percentages() {
    memez_fees::new(
        vector[
            vector[7_000, 3_000, 2],
            vector[5_000, 5_000, 30],
            vector[5_000, 5_000, 30],
            vector[10_000, 1, 6],
            vector[10_000, 0, 6],
            VESTING_PERIODS,
        ],
        vector[vector[@0x0, @0x1], vector[@0x1], vector[@0x2], vector[@0x3]],
    );
}

#[test, expected_failure(abort_code = memez_errors::EInvalidPercentages, location = memez_fees)]
fun test_new_invalid_allocation_percentages() {
    memez_fees::new(
        vector[
            vector[7_000, 3_000, 2],
            vector[5_000, 5_000, 30],
            vector[5_000, 5_000, 30],
            vector[10_000, 0, 6],
            vector[10_000, 1, 1, 6],
            VESTING_PERIODS,
        ],
        vector[vector[@0x0, @0x1], vector[@0x1], vector[@0x2], vector[@0x3]],
    );
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EInvalidCreationFeeConfig,
        location = memez_fees,
    ),
]
fun test_new_wrong_creation_recipients() {
    memez_fees::new(
        vector[
            vector[7_000, 3_000, 2],
            vector[5_000, 5_000, 0, 30],
            vector[5_000, 5_000, 0, 30],
            vector[10_000, 0, 6],
            vector[10_000, 0, 6],
            VESTING_PERIODS,
        ],
        vector[vector[@0x0], vector[@0x1], vector[@0x2], vector[@0x3]],
    );
}

fun default_fees(): MemezFees {
    let fees = memez_fees::new(
        vector[
            vector[7_000, 3_000, 2 * POW_9],
            vector[5_000, 2_500, 2_500, 200],
            vector[2_500, 2_500, 5_000, 100],
            vector[4_000, 1_000, 2_500, 2_500, TEN_PERCENT],
            vector[3_000, 3_500, 3_500, 2000],
            VESTING_PERIODS,
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
