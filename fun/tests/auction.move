#[test_only]
module memez_fun::memez_auction_tests;

use interest_access_control::access_control;
use interest_bps::bps;
use interest_math::u64;
use memez::memez::MEMEZ;
use memez_fun::{
    memez_allowed_versions,
    memez_auction::{Self, Auction},
    memez_auction_config::{Self, AuctionConfig},
    memez_config::{Self, MemezConfig},
    memez_errors,
    memez_fees,
    memez_fun::{Self, MemezFun},
    memez_metadata,
    memez_test_helpers::add_fee
};
use memez_vesting::memez_vesting::MemezVesting;
use sui::{
    clock::{Self, Clock},
    coin::{mint_for_testing, create_treasury_cap_for_testing, Coin},
    sui::SUI,
    test_scenario::{Self as ts, Scenario},
    test_utils::{assert_eq, destroy}
};

const ADMIN: address = @0x1;

const STAKE_HOLDER: address = @0x2;

// @dev Sui Decimal Scale
const POW_9: u64 = 1__000_000_000;

const MAX_BPS: u64 = 10_000;

const THIRTY_MINUTES_MS: u64 = 30 * 60 * 1_000;

const DEV_ALLOCATION: u64 = 100;
const TARGET_LIQUIDITY: u64 = 10_000 * POW_9;
const PROVISION_LIQUIDITY: u64 = 500;
const SEED_LIQUIDITY: u64 = 1;

const VESTING_PERIOD: u64 = THIRTY_MINUTES_MS * 10;

const DEV: address = @0x2;

const TEN_PERCENT: u64 = MAX_BPS / 10;

public struct Meme has drop ()

public struct MigrationWitness has drop ()

public struct World {
    config: MemezConfig,
    clock: Clock,
    scenario: Scenario,
}

public struct InvalidQuote()

public struct ConfigurableWitness()

public struct DefaultKey()

#[test]
fun test_new() {
    let mut world = start();

    let total_supply = 2_500_000_000 * POW_9;

    let start_time = 100;

    world.clock.increment_for_testing(start_time);

    let witness = access_control::sign_in_for_testing<MEMEZ>(0);

    world.config.set_meme_referrer_fee<DefaultKey>(&witness, 200, world.scenario.ctx());
    world.config.set_quote_referrer_fee<DefaultKey>(&witness, 100, world.scenario.ctx());

    let fees = world.config.fees<DefaultKey>();

    let auction_config = default_auction_config(total_supply);

    let mut memez_fun = set_up_pool(&mut world, auction_config);

    assert_eq(memez_auction::start_time<Meme, SUI>(&mut memez_fun), start_time);

    let expected_allocation_value = bps::new(fees.payloads()[4].payload_value()).calc(total_supply);

    assert_eq(memez_auction::auction_duration<Meme, SUI>(&mut memez_fun), THIRTY_MINUTES_MS);
    assert_eq(
        memez_auction::initial_reserve<Meme, SUI>(&mut memez_fun),
        total_supply - expected_allocation_value - auction_config.liquidity_provision() - auction_config.seed_liquidity(),
    );
    assert_eq(
        memez_auction::meme_reserve<Meme, SUI>(&mut memez_fun),
        total_supply - expected_allocation_value - auction_config.liquidity_provision() - auction_config.seed_liquidity(),
    );
    assert_eq(
        memez_auction::allocation<Meme, SUI>(&mut memez_fun).value(),
        expected_allocation_value,
    );
    assert_eq(
        memez_auction::liquidity_provision<Meme, SUI>(&mut memez_fun),
        auction_config.liquidity_provision(),
    );

    let fr = memez_auction::fixed_rate<Meme, SUI>(&mut memez_fun);

    assert_eq(fr.quote_raise_amount(), auction_config.target_quote_liquidity());
    assert_eq(fr.meme_sale_amount(), auction_config.seed_liquidity());
    assert_eq(fr.meme_balance().value(), auction_config.seed_liquidity());
    assert_eq(fr.quote_balance().value(), 0);
    assert_eq(fr.meme_referrer_fee().value(), 200);
    assert_eq(fr.quote_referrer_fee().value(), 100);

    memez_fun.assert_is_bonding();

    destroy(memez_fun);

    world.end();
}

#[test]
fun test_decrease_auction_mechanism() {
    let mut world = start();

    let total_supply = 1_000_000_000 * POW_9;

    let start_time = 100;

    world.clock.increment_for_testing(start_time);

    let auction_config = default_auction_config(total_supply);

    let mut memez_fun = set_up_pool(&mut world, auction_config);

    let meme_balance_t0 = memez_auction::fixed_rate(&mut memez_fun).meme_balance().value();

    let market_cap_t0 = memez_auction::market_cap(&mut memez_fun, &world.clock, 9, total_supply);

    // almost 100 million at time 0
    assert_eq(market_cap_t0 > 99_000_000 * POW_9, true);

    let final_meme_balance = memez_auction::initial_reserve(&mut memez_fun);

    world.clock.increment_for_testing(THIRTY_MINUTES_MS / 2);

    let market_cap_t1 = memez_auction::market_cap(&mut memez_fun, &world.clock, 9, total_supply);

    assert_eq(
        memez_auction::current_meme_balance(&mut memez_fun, &world.clock),
        final_meme_balance / 2 + meme_balance_t0,
    );

    // @dev After 15 minutes the market is lower than 25_000 Sui
    assert_eq(25_000 * POW_9 > market_cap_t1, true);
    assert_eq(20_000 * POW_9 < market_cap_t1, true);

    world.clock.increment_for_testing(THIRTY_MINUTES_MS / 2);

    let market_cap_t2 = memez_auction::market_cap(&mut memez_fun, &world.clock, 9, total_supply);

    assert_eq(
        memez_auction::current_meme_balance(&mut memez_fun, &world.clock),
        final_meme_balance + meme_balance_t0,
    );

    // @dev After 30 minutes the market is lower than 11_000 Sui
    assert_eq(11_000 * POW_9 > market_cap_t2, true);

    destroy(memez_fun);

    world.end();
}

#[test]
fun test_end_to_end() {
    let mut world = start();

    let total_supply = 1_000_000_000 * POW_9;

    let start_time = 100;

    world.clock.increment_for_testing(start_time);

    let auction_config = default_auction_config(total_supply);

    let mut memez_fun = set_up_pool(&mut world, auction_config);

    world.scenario.next_tx(ADMIN);

    let creation_fee = world.scenario.take_from_address<Coin<SUI>>(ADMIN);

    assert_eq(creation_fee.burn_for_testing(), 2 * POW_9);

    let fr = memez_auction::fixed_rate(&mut memez_fun);

    let initial_meme_balance = fr.meme_balance().value();

    let quote_swap_fee = fr.quote_swap_fee().calculate(1_000 * POW_9);

    let amounts = fr.pump_amount(1_000 * POW_9, 0);

    let (excess_quote_coin, meme_coin) = memez_auction::pump(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(1_000 * POW_9, world.scenario.ctx()),
        option::none(),
        option::none(),
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    assert_eq(excess_quote_coin.burn_for_testing(), amounts[0]);
    assert_eq(amounts[0], 0);

    assert_eq(meme_coin.burn_for_testing(), amounts[1]);

    let fr = memez_auction::fixed_rate(&mut memez_fun);

    assert_eq(fr.quote_balance().value(), 1_000 * POW_9 - quote_swap_fee);
    assert_eq(fr.meme_balance().value(), initial_meme_balance - amounts[1] - amounts[3]);

    memez_fun.assert_is_bonding();

    // @dev Advance 5 minutes to increase liquidity
    world.clock.increment_for_testing(THIRTY_MINUTES_MS / 6);

    memez_auction::drip_for_testing(&mut memez_fun, &world.clock);

    let amounts2 = memez_auction::fixed_rate(&mut memez_fun).pump_amount(1_000 * POW_9, 0);

    // Get at cheaper value
    assert_eq(amounts2[1] > amounts[1], true);

    let (excess_quote_coin_2, meme_coin_2) = memez_auction::pump(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(1_000 * POW_9, world.scenario.ctx()),
        option::none(),
        option::none(),
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    assert_eq(excess_quote_coin_2.burn_for_testing(), amounts2[0]);
    assert_eq(amounts2[0], 0);

    assert_eq(meme_coin_2.burn_for_testing(), amounts2[1]);

    let fr = memez_auction::fixed_rate(&mut memez_fun);

    let amounts = fr.dump_amount(amounts2[1] / 2, 0);

    let sui_coin = memez_auction::dump(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(amounts2[1] / 2, world.scenario.ctx()),
        option::none(),
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    assert_eq(sui_coin.burn_for_testing(), amounts[0]);

    let fr = memez_auction::fixed_rate(&mut memez_fun);

    let remaining_amount_to_migrate = fr.quote_raise_amount() - fr.quote_balance().value();

    let amounts3 = fr.pump_amount(
        add_fee(remaining_amount_to_migrate, 30) + 2_000 * POW_9,
        0,
    );

    let (excess_quote_coin, meme_coin) = memez_auction::pump(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(
            add_fee(remaining_amount_to_migrate, 30) + 2_000 * POW_9,
            world.scenario.ctx(),
        ),
        option::none(),
        option::none(),
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    assert_eq(excess_quote_coin.burn_for_testing(), amounts3[0]);
    assert_eq(2_000 * POW_9, amounts3[0]);
    assert_eq(meme_coin.burn_for_testing(), amounts3[1]);

    memez_fun.assert_is_migrating();

    let migrator = memez_auction::migrate(
        &mut memez_fun,
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    let migration_fee_value = 1_000 * POW_9;

    let (dev, meme_balance, sui_balance) = migrator.destroy(MigrationWitness());

    let auction_config = default_auction_config(total_supply);

    assert_eq(sui_balance.value(), 10_000 * POW_9 - migration_fee_value);
    assert_eq(meme_balance.value(), auction_config.liquidity_provision());
    assert_eq(dev, ADMIN);

    sui_balance.destroy_for_testing();
    meme_balance.destroy_for_testing();

    memez_fun.assert_migrated();

    world.scenario.next_tx(DEV);

    let migration_fee = world.scenario.take_from_address<Coin<SUI>>(ADMIN);

    assert_eq(migration_fee.burn_for_testing(), migration_fee_value);

    memez_auction::distribute_stake_holders_allocation(
        &mut memez_fun,
        &world.clock,
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    world.scenario.next_tx(DEV);

    let dev_allocation = world.scenario.take_from_address<MemezVesting<Meme>>(DEV);

    let fees = world.config.fees<DefaultKey>();

    let expected_allocation_value = bps::new(fees.payloads()[4].payload_value()).calc(total_supply);

    assert_eq(dev_allocation.balance(), expected_allocation_value);

    destroy(memez_fun);
    destroy(dev_allocation);

    world.end();
}

#[test]
fun test_end_to_end_with_stake_holders() {
    let mut world = start();

    let witness = access_control::sign_in_for_testing<MEMEZ>(0);

    world
        .config
        .set_fees<DefaultKey>(
            &witness,
            vector[
                vector[MAX_BPS / 2, MAX_BPS / 2, 2 * POW_9],
                vector[3_000, 7_000, 30],
                vector[3_000, 7_000, 30],
                vector[2_000, 8_000, TEN_PERCENT],
                vector[0, MAX_BPS, 500],
                vector[VESTING_PERIOD, VESTING_PERIOD + 1],
            ],
            vector[vector[ADMIN, STAKE_HOLDER], vector[ADMIN], vector[ADMIN], vector[ADMIN]],
            world.scenario.ctx(),
        );
    let total_supply = 1_000_000_000 * POW_9;

    let start_time = 100;

    world.clock.increment_for_testing(start_time);

    let (mut memez_fun, metadata_cap) = memez_auction::new<Meme, SUI, DefaultKey, MigrationWitness>(
        &world.config,
        &world.clock,
        create_treasury_cap_for_testing(world.scenario.ctx()),
        mint_for_testing(2_000_000_000, world.scenario.ctx()),
        default_auction_config(total_supply),
        memez_metadata::new_for_test(world.scenario.ctx()),
        vector[STAKE_HOLDER],
        false,
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    destroy(metadata_cap);

    world.scenario.next_tx(ADMIN);

    // 50% of the creation fee is paid to the admin
    assert_eq(world.scenario.take_from_address<Coin<SUI>>(ADMIN).burn_for_testing(), POW_9);

    // 50% of the creation fee is paid to the stake holder
    assert_eq(world.scenario.take_from_address<Coin<SUI>>(STAKE_HOLDER).burn_for_testing(), POW_9);

    let fr = memez_auction::fixed_rate(&mut memez_fun);

    let initial_meme_balance = fr.meme_balance().value();

    let amounts = fr.pump_amount(1_000 * POW_9, 0);

    let clock = &world.clock;
    let ctx = world.scenario.ctx();

    let (excess_quote_coin, meme_coin) = memez_auction::pump(
        &mut memez_fun,
        clock,
        mint_for_testing(1_000 * POW_9, ctx),
        option::none(),
        option::none(),
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        ctx,
    );

    assert_eq(meme_coin.burn_for_testing(), amounts[1]);
    assert_eq(excess_quote_coin.burn_for_testing(), amounts[0]);
    assert_eq(amounts[0], 0);

    world.scenario.next_tx(ADMIN);

    let fr = memez_auction::fixed_rate(&mut memez_fun);

    let quote_swap_fee = fr.quote_swap_fee().calculate(1_000 * POW_9);

    // 70% of the swap fee is paid to the admin
    assert_eq(
        world.scenario.take_from_address<Coin<SUI>>(ADMIN).burn_for_testing(),
        quote_swap_fee * 3_000 / 10_000,
    );

    // 30% of the swap fee is paid to the stake holder
    assert_eq(
        world.scenario.take_from_address<Coin<SUI>>(STAKE_HOLDER).burn_for_testing(),
        quote_swap_fee * 7_000 / 10_000,
    );

    let fr = memez_auction::fixed_rate(&mut memez_fun);

    assert_eq(fr.quote_balance().value(), 1_000 * POW_9 - quote_swap_fee);
    assert_eq(fr.meme_balance().value(), initial_meme_balance - amounts[1] - amounts[3]);

    memez_fun.assert_is_bonding();

    // @dev Advance 5 minutes to increase liquidity
    world.clock.increment_for_testing(THIRTY_MINUTES_MS / 6);

    memez_auction::drip_for_testing(&mut memez_fun, &world.clock);

    let fr = memez_auction::fixed_rate(&mut memez_fun);

    let amounts2 = fr.pump_amount(1_000 * POW_9, 0);
    // Get at cheaper value
    assert_eq(amounts2[1] > amounts[1], true);

    let (excess_quote_coin_2, meme_coin_2) = memez_auction::pump(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(1_000 * POW_9, world.scenario.ctx()),
        option::none(),
        option::none(),
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    assert_eq(meme_coin_2.burn_for_testing(), amounts2[1]);
    assert_eq(excess_quote_coin_2.burn_for_testing(), amounts2[0]);
    assert_eq(amounts2[0], 0);

    let fr = memez_auction::fixed_rate(&mut memez_fun);

    let amounts3 = fr.dump_amount(amounts2[1] / 2, 0);

    let sui_coin = memez_auction::dump(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(amounts2[1] / 2, world.scenario.ctx()),
        option::none(),
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    assert_eq(sui_coin.burn_for_testing(), amounts3[0]);

    let fr = memez_auction::fixed_rate(&mut memez_fun);

    let remaining_amount_to_migrate = 10_000 * POW_9 - fr.quote_balance().value();

    let amounts4 = fr.pump_amount(
        add_fee(remaining_amount_to_migrate, 30) + 3_000 * POW_9,
        0,
    );

    let (excess_quote_coin, meme_coin) = memez_auction::pump(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(
            add_fee(remaining_amount_to_migrate, 30) + 3_000 * POW_9,
            world.scenario.ctx(),
        ),
        option::none(),
        option::none(),
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    assert_eq(meme_coin.burn_for_testing(), amounts4[1]);
    assert_eq(excess_quote_coin.burn_for_testing(), amounts4[0]);
    assert_eq(amounts4[0], 3_000 * POW_9);

    memez_fun.assert_is_migrating();

    world.scenario.next_tx(STAKE_HOLDER);

    // Burn all swap coins

    // 2 Pump swaps so each have 2 sui coins
    world.scenario.take_from_address<Coin<SUI>>(ADMIN).burn_for_testing();
    world.scenario.take_from_address<Coin<SUI>>(STAKE_HOLDER).burn_for_testing();
    world.scenario.take_from_address<Coin<SUI>>(ADMIN).burn_for_testing();
    world.scenario.take_from_address<Coin<SUI>>(STAKE_HOLDER).burn_for_testing();

    let migrator = memez_auction::migrate(
        &mut memez_fun,
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    let (_, meme_balance, sui_balance) = migrator.destroy(MigrationWitness());

    let auction_config = default_auction_config(total_supply);

    let migration_fee_value = 1_000 * POW_9;

    assert_eq(sui_balance.value(), 10_000 * POW_9 - migration_fee_value);
    assert_eq(meme_balance.value(), auction_config.liquidity_provision());

    sui_balance.destroy_for_testing();
    meme_balance.destroy_for_testing();

    memez_fun.assert_migrated();

    world.scenario.next_tx(DEV);

    assert_eq(
        world.scenario.take_from_address<Coin<SUI>>(ADMIN).burn_for_testing(),
        migration_fee_value * 2_000 / 10_000,
    );
    assert_eq(
        world.scenario.take_from_address<Coin<SUI>>(STAKE_HOLDER).burn_for_testing(),
        migration_fee_value * 8_000 / 10_000,
    );

    memez_auction::distribute_stake_holders_allocation(
        &mut memez_fun,
        &world.clock,
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    world.scenario.next_tx(DEV);

    let vested_meme_coin = world.scenario.take_from_address<MemezVesting<Meme>>(STAKE_HOLDER);

    assert_eq(vested_meme_coin.balance(), u64::mul_div_down(total_supply, 500, 10_000));
    assert_eq(vested_meme_coin.duration(), VESTING_PERIOD + 1);

    destroy(memez_fun);
    destroy(vested_meme_coin);
    world.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EOutdatedPackageVersion,
        location = memez_allowed_versions,
    ),
]
fun test_distribute_stake_holders_allocation_invalid_version() {
    let mut world = start();

    let auction_config = default_auction_config(1_000_000_000 * POW_9);

    let mut memez_fun = set_up_pool(&mut world, auction_config);

    memez_auction::distribute_stake_holders_allocation(
        &mut memez_fun,
        &world.clock,
        memez_allowed_versions::get_invalid_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    destroy(memez_fun);
    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ENotMigrated, location = memez_fun)]
fun test_distribute_stake_holders_allocation_not_migrating() {
    let mut world = start();

    let auction_config = default_auction_config(1_000_000_000 * POW_9);

    let mut memez_fun = set_up_pool(&mut world, auction_config);

    memez_auction::distribute_stake_holders_allocation(
        &mut memez_fun,
        &world.clock,
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    destroy(memez_fun);
    world.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EInvalidDynamicStakeHolders,
        location = memez_fees,
    ),
]
fun new_invalid_dynamic_stake_holders() {
    let mut world = start();

    let (memez_fun, metadata_cap) = memez_auction::new<Meme, SUI, DefaultKey, MigrationWitness>(
        &world.config,
        &world.clock,
        create_treasury_cap_for_testing(world.scenario.ctx()),
        mint_for_testing(2_000_000_000, world.scenario.ctx()),
        default_auction_config(1_000_000_000 * POW_9),
        memez_metadata::new_for_test(world.scenario.ctx()),
        vector[STAKE_HOLDER],
        false,
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    destroy(metadata_cap);
    destroy(memez_fun);
    world.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EMigratorWitnessNotSupported,
        location = memez_config,
    ),
]
fun new_invalid_migrator_witness() {
    let mut world = start();

    let (memez_fun, metadata_cap) = memez_auction::new<Meme, SUI, DefaultKey, DefaultKey>(
        &world.config,
        &world.clock,
        create_treasury_cap_for_testing(world.scenario.ctx()),
        mint_for_testing(2_000_000_000, world.scenario.ctx()),
        default_auction_config(1_000_000_000 * POW_9),
        memez_metadata::new_for_test(world.scenario.ctx()),
        vector[],
        false,
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    destroy(metadata_cap);
    destroy(memez_fun);
    world.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EOutdatedPackageVersion,
        location = memez_allowed_versions,
    ),
]
fun new_invalid_version() {
    let mut world = start();

    let (memez_fun, metadata_cap) = memez_auction::new<Meme, SUI, DefaultKey, MigrationWitness>(
        &world.config,
        &world.clock,
        create_treasury_cap_for_testing(world.scenario.ctx()),
        mint_for_testing(2_000_000_000, world.scenario.ctx()),
        default_auction_config(1_000_000_000 * POW_9),
        memez_metadata::new_for_test(world.scenario.ctx()),
        vector[],
        false,
        memez_allowed_versions::get_invalid_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    destroy(metadata_cap);
    destroy(memez_fun);
    world.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EQuoteCoinNotSupported,
        location = memez_config,
    ),
]
fun new_invalid_quote_type() {
    let mut world = start();

    let config = &world.config;
    let clock = &world.clock;

    let auction_config = default_auction_config(1_000_000_000 * POW_9);

    let ctx = world.scenario.ctx();

    let (memez_fun, metadata_cap) = memez_auction::new<
        Meme,
        InvalidQuote,
        DefaultKey,
        MigrationWitness,
    >(
        config,
        clock,
        create_treasury_cap_for_testing(ctx),
        mint_for_testing(2_000_000_000, ctx),
        auction_config,
        memez_metadata::new_for_test(ctx),
        vector[],
        false,
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        ctx,
    );

    destroy(metadata_cap);
    destroy(memez_fun);
    world.end();
}

#[test, expected_failure(abort_code = memez_errors::EInsufficientValue, location = memez_fees)]
fun new_low_creation_fee() {
    let mut world = start();

    let (memez_fun, metadata_cap) = memez_auction::new<Meme, SUI, DefaultKey, MigrationWitness>(
        &world.config,
        &world.clock,
        create_treasury_cap_for_testing(world.scenario.ctx()),
        mint_for_testing(2_000_000_000 - 1, world.scenario.ctx()),
        default_auction_config(1_000_000_000 * POW_9),
        memez_metadata::new_for_test(world.scenario.ctx()),
        vector[],
        false,
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    destroy(metadata_cap);
    destroy(memez_fun);
    world.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EOutdatedPackageVersion,
        location = memez_allowed_versions,
    ),
]
fun pump_invalid_version() {
    let mut world = start();

    let auction_config = default_auction_config(1_000_000_000 * POW_9);

    let mut memez_fun = set_up_pool(&mut world, auction_config);

    let (excess_quote_coin, meme_coin) = memez_auction::pump(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(1_000 * POW_9, world.scenario.ctx()),
        option::none(),
        option::none(),
        memez_allowed_versions::get_invalid_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    destroy(memez_fun);
    destroy(excess_quote_coin);
    destroy(meme_coin);
    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ENotBonding, location = memez_fun)]
fun pump_is_not_bonding() {
    let mut world = start();

    let auction_config = default_auction_config(1_000_000_000 * POW_9);

    let mut memez_fun = set_up_pool(&mut world, auction_config);

    let (excess_quote_coin, meme_coin) = memez_auction::pump(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(add_fee(10_000 * POW_9, 30), world.scenario.ctx()),
        option::none(),
        option::none(),
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    destroy(excess_quote_coin);
    destroy(meme_coin);

    let (excess_quote_coin_2, meme_coin_2) = memez_auction::pump(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(10_000 * POW_9, world.scenario.ctx()),
        option::none(),
        option::none(),
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    destroy(excess_quote_coin_2);
    destroy(meme_coin_2);
    destroy(memez_fun);

    world.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EOutdatedPackageVersion,
        location = memez_allowed_versions,
    ),
]
fun dump_invalid_version() {
    let mut world = start();

    let auction_config = default_auction_config(1_000_000_000 * POW_9);

    let mut memez_fun = set_up_pool(&mut world, auction_config);

    memez_auction::dump(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(POW_9, world.scenario.ctx()),
        option::none(),
        memez_allowed_versions::get_invalid_allowed_versions_for_testing(),
        world.scenario.ctx(),
    ).burn_for_testing();

    destroy(memez_fun);
    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ENotBonding, location = memez_fun)]
fun dump_is_not_bonding() {
    let mut world = start();

    let auction_config = default_auction_config(1_000_000_000 * POW_9);

    let mut memez_fun = set_up_pool(&mut world, auction_config);

    let (excess_quote_coin, meme_coin) = memez_auction::pump(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(add_fee(10_000 * POW_9, 30), world.scenario.ctx()),
        option::none(),
        option::none(),
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    destroy(excess_quote_coin);
    destroy(meme_coin);

    memez_auction::dump(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(POW_9, world.scenario.ctx()),
        option::none(),
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    ).burn_for_testing();

    destroy(memez_fun);
    world.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EOutdatedPackageVersion,
        location = memez_allowed_versions,
    ),
]
fun migrate_invalid_version() {
    let mut world = start();

    let auction_config = default_auction_config(1_000_000_000 * POW_9);

    let mut memez_fun = set_up_pool(&mut world, auction_config);

    let migrator = memez_auction::migrate(
        &mut memez_fun,
        memez_allowed_versions::get_invalid_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    destroy(migrator);

    abort
}

#[test, expected_failure(abort_code = memez_errors::ENotMigrating, location = memez_fun)]
fun migrate_is_not_migrating() {
    let mut world = start();

    let auction_config = default_auction_config(1_000_000_000 * POW_9);

    let mut memez_fun = set_up_pool(&mut world, auction_config);

    let migrator = memez_auction::migrate(
        &mut memez_fun,
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    destroy(migrator);

    abort
}

fun set_up_pool(world: &mut World, auction_config: AuctionConfig): MemezFun<Auction, Meme, SUI> {
    let ctx = world.scenario.ctx();

    let (memez_fun, metadata_cap) = memez_auction::new<Meme, SUI, DefaultKey, MigrationWitness>(
        &world.config,
        &world.clock,
        create_treasury_cap_for_testing(ctx),
        mint_for_testing(2_000_000_000, ctx),
        auction_config,
        memez_metadata::new_for_test(ctx),
        vector[],
        false,
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        ctx,
    );

    destroy(metadata_cap);

    memez_fun
}

fun start(): World {
    let mut scenario = ts::begin(ADMIN);

    memez_config::init_for_testing(scenario.ctx());
    memez_allowed_versions::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let mut config = scenario.take_shared<MemezConfig>();

    let witness = access_control::sign_in_for_testing<MEMEZ>(0);

    config.add_quote_coin<DefaultKey, SUI>(&witness, scenario.ctx());

    config.add_migrator_witness<DefaultKey, MigrationWitness>(&witness, scenario.ctx());

    config.set_fees<DefaultKey>(
        &witness,
        vector[
            vector[MAX_BPS, 2 * POW_9],
            vector[MAX_BPS, 30],
            vector[MAX_BPS, 30],
            vector[MAX_BPS, TEN_PERCENT],
            vector[MAX_BPS, DEV_ALLOCATION],
            vector[VESTING_PERIOD],
        ],
        vector[vector[ADMIN], vector[ADMIN], vector[ADMIN], vector[DEV]],
        scenario.ctx(),
    );

    let clock = clock::create_for_testing(scenario.ctx());

    World { config, clock, scenario }
}

fun default_auction_config(total_supply: u64): AuctionConfig {
    memez_auction_config::new(vector[
        THIRTY_MINUTES_MS,
        TARGET_LIQUIDITY,
        PROVISION_LIQUIDITY,
        SEED_LIQUIDITY,
        total_supply,
    ])
}

fun end(world: World) {
    destroy(world);
}
