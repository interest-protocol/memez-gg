#[test_only]
module memez_fun::memez_stable_tests;

use interest_access_control::access_control;
use interest_bps::bps;
use memez::memez::MEMEZ;
use memez_fun::{
    memez_allowed_versions,
    memez_config::{Self, MemezConfig},
    memez_errors,
    memez_fees,
    memez_fixed_rate,
    memez_fun::{Self, MemezFun},
    memez_metadata,
    memez_stable::{Self, Stable},
    memez_stable_config::{Self, StableConfig}
};
use memez_vesting::memez_vesting::MemezVesting;
use sui::{
    balance,
    clock,
    coin::{Self, mint_for_testing, create_treasury_cap_for_testing, Coin},
    sui::SUI,
    test_scenario::{Self as ts, Scenario},
    test_utils::{assert_eq, destroy}
};

const ADMIN: address = @0x1;

const STAKE_HOLDER: address = @0x2;

const DAY: u64 = 86_400_000;

const POW_9: u64 = 1__000_000_000;

const DEV: address = @0x2;

const MAX_BPS: u64 = 10_000;

const LIQUIDITY_PROVISION: u64 = 500;

const MEME_SALE_AMOUNT: u64 = 2_000;

const MAX_TARGET_SUI_LIQUIDITY: u64 = 10_000 * POW_9;

const VESTING_PERIOD: u64 = 250;

const TEN_PERCENT: u64 = MAX_BPS / 10;

public struct World {
    config: MemezConfig,
    scenario: Scenario,
}

public struct DefaultKey has drop ()

public struct Meme has drop ()

public struct MigrationWitness has drop ()

public struct InvalidQuote()

public struct ConfigurableWitness has drop ()

#[test]
fun test_new_coin() {
    let mut world = start();

    let total_supply = POW_9 * POW_9;

    let dev_allocation = POW_9 / 10;

    let stable_config = stable_default_config(total_supply);

    let mut memez_fun = set_up_pool(
        &mut world,
        stable_config,
        vector[dev_allocation, DAY],
    );

    assert_eq(memez_stable::dev_allocation(&mut memez_fun), dev_allocation);
    assert_eq(
        memez_stable::liquidity_provision(&mut memez_fun),
        stable_config.liquidity_provision(),
    );
    assert_eq(memez_stable::dev_vesting_period(&mut memez_fun), DAY);

    let fr = memez_stable::fixed_rate(&mut memez_fun);

    assert_eq(fr.memez_fun(), object::id_address(&memez_fun));
    assert_eq(fr.quote_raise_amount(), MAX_TARGET_SUI_LIQUIDITY);
    assert_eq(fr.meme_sale_amount(), stable_config.meme_sale_amount());
    assert_eq(fr.quote_balance().value(), 0);
    assert_eq(fr.meme_balance().value(), stable_config.meme_sale_amount());

    assert_eq(
        memez_stable::meme_reserve(&mut memez_fun).value(),
        total_supply - dev_allocation - stable_config.meme_sale_amount() - stable_config.liquidity_provision(),
    );

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
fun test_new_invalid_migrator_witness() {
    let mut world = start();

    let total_supply = POW_9 * POW_9;

    let dev_allocation = POW_9 / 10;

    let (memez_fun, metadata_cap) = memez_stable::new<Meme, SUI, DefaultKey, DefaultKey>(
        &world.config,
        create_treasury_cap_for_testing(world.scenario.ctx()),
        mint_for_testing(2_000_000_000, world.scenario.ctx()),
        stable_default_config(total_supply),
        memez_metadata::new_for_test(world.scenario.ctx()),
        vector[dev_allocation, DAY],
        vector[STAKE_HOLDER],
        DEV,
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
        abort_code = memez_errors::EInvalidDynamicStakeHolders,
        location = memez_fees,
    ),
]
fun test_new_invalid_dynamic_stake_holders() {
    let mut world = start();

    let total_supply = POW_9 * POW_9;

    let dev_allocation = POW_9 / 10;

    let (memez_fun, metadata_cap) = memez_stable::new<Meme, SUI, DefaultKey, MigrationWitness>(
        &world.config,
        create_treasury_cap_for_testing(world.scenario.ctx()),
        mint_for_testing(2_000_000_000, world.scenario.ctx()),
        stable_default_config(total_supply),
        memez_metadata::new_for_test(world.scenario.ctx()),
        vector[dev_allocation, DAY],
        vector[STAKE_HOLDER, STAKE_HOLDER],
        DEV,
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
fun test_new_invalid_version() {
    let mut world = start();

    let total_supply = POW_9 * POW_9;

    let dev_allocation = POW_9 / 10;

    let (memez_fun, metadata_cap) = memez_stable::new<Meme, SUI, DefaultKey, MigrationWitness>(
        &world.config,
        create_treasury_cap_for_testing(world.scenario.ctx()),
        mint_for_testing(2_000_000_000, world.scenario.ctx()),
        stable_default_config(total_supply),
        memez_metadata::new_for_test(world.scenario.ctx()),
        vector[dev_allocation, DAY],
        vector[STAKE_HOLDER],
        DEV,
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
fun test_new_invalid_quote_type() {
    let mut world = start();

    let total_supply = POW_9 * POW_9;

    let dev_allocation = POW_9 / 10;

    let (memez_fun, metadata_cap) = memez_stable::new<
        Meme,
        InvalidQuote,
        DefaultKey,
        MigrationWitness,
    >(
        &world.config,
        create_treasury_cap_for_testing(world.scenario.ctx()),
        mint_for_testing(2_000_000_000, world.scenario.ctx()),
        stable_default_config(total_supply),
        memez_metadata::new_for_test(world.scenario.ctx()),
        vector[dev_allocation, DAY],
        vector[STAKE_HOLDER],
        DEV,
        false,
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    destroy(metadata_cap);
    destroy(memez_fun);
    world.end();
}

#[test]
fun test_coin_end_to_end() {
    let mut world = start();

    let total_supply = POW_9 * POW_9;

    let dev_allocation = POW_9 / 10;

    let stable_config = stable_default_config(total_supply);

    let mut memez_fun = set_up_pool(
        &mut world,
        stable_config,
        vector[dev_allocation, DAY],
    );

    world.scenario.next_tx(ADMIN);

    let creation_fee = world.scenario.take_from_address<Coin<SUI>>(ADMIN);

    assert_eq(creation_fee.burn_for_testing(), 2 * POW_9);

    let mut fr = memez_fixed_rate::new<Meme, SUI>(
        MAX_TARGET_SUI_LIQUIDITY,
        balance::create_for_testing(stable_config.meme_sale_amount()),
        world.config.fees<DefaultKey>().meme_swap(vector[STAKE_HOLDER]),
        world.config.fees<DefaultKey>().quote_swap(vector[STAKE_HOLDER]),
        bps::new(0),
        bps::new(0),
    );

    let amounts = fr.pump_amount(1000 * POW_9, 0);

    let (excess_sui_coin, meme_coin) = memez_stable::pump(
        &mut memez_fun,
        coin::mint_for_testing(1000 * POW_9, world.scenario.ctx()),
        option::none(),
        option::none(),
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    assert_eq(excess_sui_coin.burn_for_testing(), amounts[0]);
    assert_eq(0, amounts[0]);
    assert_eq(meme_coin.burn_for_testing(), amounts[1]);

    memez_fun.assert_is_bonding();

    let (_, x, y) = fr.pump(
        coin::mint_for_testing(1000 * POW_9, world.scenario.ctx()),
        option::none(),
        world.scenario.ctx(),
    );

    x.burn_for_testing();
    y.burn_for_testing();

    let dump_amounts = fr.dump_amount(amounts[1], 0);

    let sui_coin = memez_stable::dump(
        &mut memez_fun,
        coin::mint_for_testing(amounts[1], world.scenario.ctx()),
        option::none(),
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    assert_eq(sui_coin.burn_for_testing(), dump_amounts[0]);

    let (excess_sui_coin, meme_coin) = memez_stable::pump(
        &mut memez_fun,
        coin::mint_for_testing(1000 * POW_9 + MAX_TARGET_SUI_LIQUIDITY, world.scenario.ctx()),
        option::none(),
        option::none(),
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    meme_coin.burn_for_testing();
    excess_sui_coin.burn_for_testing();

    memez_fun.assert_is_migrating();

    let migrator = memez_stable::migrate(
        &mut memez_fun,
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    let (_, meme_balance_after, sui_balance_after) = migrator.destroy(MigrationWitness());

    let migration_fee_value = 1_000 * POW_9;

    assert_eq(
        sui_balance_after.destroy_for_testing(),
        MAX_TARGET_SUI_LIQUIDITY - migration_fee_value,
    );
    assert_eq(
        meme_balance_after.destroy_for_testing(),
        stable_config.liquidity_provision(),
    );

    memez_fun.assert_migrated();

    world.scenario.next_tx(DEV);

    let migration_fee = world.scenario.take_from_address<Coin<SUI>>(ADMIN);

    assert_eq(migration_fee.burn_for_testing(), migration_fee_value);

    destroy(fr);
    destroy(memez_fun);
    world.end();
}

#[test]
fun test_distribute_stake_holders_allocation() {
    let mut world = start();

    let total_supply = POW_9 * POW_9;

    let dev_allocation = POW_9 / 10;

    let target_sui_liquidity = 10_000 * POW_9;

    let witness = access_control::sign_in_for_testing<MEMEZ>(0);

    world
        .config
        .set_fees<DefaultKey>(
            &witness,
            vector[
                vector[MAX_BPS, 2 * POW_9],
                vector[MAX_BPS, 0, 30],
                vector[MAX_BPS, 0, 30],
                vector[MAX_BPS, 0, TEN_PERCENT],
                vector[MAX_BPS / 2, MAX_BPS / 2, 500],
                vector[VESTING_PERIOD, VESTING_PERIOD + 1],
            ],
            vector[vector[ADMIN], vector[ADMIN], vector[ADMIN], vector[ADMIN]],
            world.scenario.ctx(),
        );

    let stable_config = stable_default_config(total_supply);

    let mut memez_fun = set_up_pool(
        &mut world,
        stable_config,
        vector[dev_allocation, DAY],
    );

    let mut fr = memez_fixed_rate::new<Meme, SUI>(
        MAX_TARGET_SUI_LIQUIDITY,
        balance::create_for_testing(stable_config.liquidity_provision()),
        world.config.fees<DefaultKey>().meme_swap(vector[STAKE_HOLDER]),
        world.config.fees<DefaultKey>().quote_swap(vector[STAKE_HOLDER]),
        bps::new(0),
        bps::new(0),
    );

    let amounts = fr.pump_amount(1000 * POW_9, 0);

    let (excess_sui_coin, meme_coin) = memez_stable::pump(
        &mut memez_fun,
        coin::mint_for_testing(1000 * POW_9, world.scenario.ctx()),
        option::none(),
        option::none(),
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    excess_sui_coin.burn_for_testing();
    meme_coin.burn_for_testing();

    memez_fun.assert_is_bonding();

    let swap_fee = world
        .config
        .fees<DefaultKey>()
        .quote_swap(vector[STAKE_HOLDER])
        .calculate(1000 * POW_9);

    let (_, x, y) = fr.pump(
        coin::mint_for_testing(1000 * POW_9 - swap_fee, world.scenario.ctx()),
        option::none(),
        world.scenario.ctx(),
    );

    x.burn_for_testing();
    y.burn_for_testing();

    let sui_coin = memez_stable::dump(
        &mut memez_fun,
        coin::mint_for_testing(amounts[1], world.scenario.ctx()),
        option::none(),
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    sui_coin.burn_for_testing();

    let (excess_sui_coin, meme_coin) = memez_stable::pump(
        &mut memez_fun,
        coin::mint_for_testing(1000 * POW_9 + target_sui_liquidity, world.scenario.ctx()),
        option::none(),
        option::none(),
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    meme_coin.burn_for_testing();
    excess_sui_coin.burn_for_testing();

    memez_fun.assert_is_migrating();

    let migrator = memez_stable::migrate(
        &mut memez_fun,
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    let (_, meme_balance_after, sui_balance_after) = migrator.destroy(MigrationWitness());

    sui_balance_after.destroy_for_testing();
    meme_balance_after.destroy_for_testing();

    memez_fun.assert_migrated();

    world.scenario.next_tx(DEV);

    let migration_fee = world.scenario.take_from_address<Coin<SUI>>(ADMIN);

    assert_eq(migration_fee.burn_for_testing(), 1_000 * POW_9);

    world.scenario.next_tx(DEV);

    let mut clock = clock::create_for_testing(world.scenario.ctx());

    clock.increment_for_testing(60_000);

    clock.increment_for_testing(VESTING_PERIOD);

    memez_stable::distribute_stake_holders_allocation(
        &mut memez_fun,
        &clock,
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    world.scenario.next_tx(ADMIN);

    let admin_vesting = world.scenario.take_from_address<MemezVesting<Meme>>(ADMIN);

    let stake_holder_vesting = world.scenario.take_from_address<MemezVesting<Meme>>(STAKE_HOLDER);

    let migration_fee = bps::new(500).calc_up(total_supply);

    assert_eq(admin_vesting.balance(), migration_fee / 2);
    assert_eq(stake_holder_vesting.balance(), migration_fee / 2);

    destroy(admin_vesting);
    destroy(stake_holder_vesting);

    destroy(clock);
    destroy(fr);
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
fun test_distribute_stake_holders_allocation_invalid_version() {
    let mut world = start();

    let dev_allocation = POW_9 / 10;

    let total_supply = 1_000_000_000_000_000_000;

    let stable_config = stable_default_config(total_supply);

    let mut memez_fun = set_up_pool(
        &mut world,
        stable_config,
        vector[dev_allocation, DAY],
    );

    let clock = clock::create_for_testing(world.scenario.ctx());

    memez_stable::distribute_stake_holders_allocation(
        &mut memez_fun,
        &clock,
        memez_allowed_versions::get_invalid_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    destroy(memez_fun);
    destroy(clock);

    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ENotMigrated, location = memez_fun)]
fun test_distribute_stake_holders_allocation_not_migrated() {
    let mut world = start();

    let dev_allocation = POW_9 / 10;

    let total_supply = 1_000_000_000_000_000_000;

    let stable_config = stable_default_config(total_supply);

    let mut memez_fun = set_up_pool(
        &mut world,
        stable_config,
        vector[dev_allocation, DAY],
    );

    let clock = clock::create_for_testing(world.scenario.ctx());

    memez_stable::distribute_stake_holders_allocation(
        &mut memez_fun,
        &clock,
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    destroy(memez_fun);
    destroy(clock);

    world.end();
}

#[test, expected_failure(abort_code = memez_errors::EInsufficientValue, location = memez_fees)]
fun test_new_invalid_creation_fee() {
    let mut world = start();

    let total_supply = POW_9 * POW_9;

    let dev_allocation = POW_9 / 10;

    let (memez_fun, metadata_cap) = memez_stable::new<Meme, SUI, DefaultKey, MigrationWitness>(
        &world.config,
        create_treasury_cap_for_testing(world.scenario.ctx()),
        mint_for_testing(2_000_000_000 - 1, world.scenario.ctx()),
        stable_default_config(total_supply),
        memez_metadata::new_for_test(world.scenario.ctx()),
        vector[dev_allocation, DAY],
        vector[STAKE_HOLDER, STAKE_HOLDER],
        DEV,
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

    let total_supply = POW_9 * POW_9;

    let dev_allocation = POW_9 / 10;

    let stable_config = stable_default_config(total_supply);

    let mut memez_fun = set_up_pool(
        &mut world,
        stable_config,
        vector[dev_allocation, DAY],
    );

    let (x, y) = memez_stable::pump(
        &mut memez_fun,
        coin::mint_for_testing(1000 * POW_9, world.scenario.ctx()),
        option::none(),
        option::none(),
        memez_allowed_versions::get_invalid_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    x.burn_for_testing();
    y.burn_for_testing();

    destroy(memez_fun);
    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ENotBonding, location = memez_fun)]
fun pump_is_not_bonding() {
    let mut world = start();

    let witness = access_control::sign_in_for_testing<MEMEZ>(0);

    world
        .config
        .set_fees<DefaultKey>(
            &witness,
            vector[
                vector[MAX_BPS, 2 * POW_9],
                vector[MAX_BPS, 0, 0],
                vector[MAX_BPS, 0, 0],
                vector[MAX_BPS, 0, TEN_PERCENT],
                vector[MAX_BPS / 2, MAX_BPS / 2, 500],
                vector[VESTING_PERIOD],
            ],
            vector[vector[ADMIN], vector[ADMIN], vector[ADMIN], vector[ADMIN]],
            world.scenario.ctx(),
        );

    let total_supply = POW_9 * POW_9;

    let dev_allocation = POW_9 / 10;

    let stable_config = stable_default_config(total_supply);

    let mut memez_fun = set_up_pool(
        &mut world,
        stable_config,
        vector[dev_allocation, DAY],
    );

    let (x, y) = memez_stable::pump(
        &mut memez_fun,
        coin::mint_for_testing(10_000 * POW_9, world.scenario.ctx()),
        option::none(),
        option::none(),
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    x.burn_for_testing();
    y.burn_for_testing();

    let (x, y) = memez_stable::pump(
        &mut memez_fun,
        coin::mint_for_testing(POW_9, world.scenario.ctx()),
        option::none(),
        option::none(),
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    x.burn_for_testing();
    y.burn_for_testing();

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

    let total_supply = POW_9 * POW_9;

    let dev_allocation = POW_9 / 10;

    let stable_config = stable_default_config(total_supply);

    let mut memez_fun = set_up_pool(
        &mut world,
        stable_config,
        vector[dev_allocation, DAY],
    );

    let (x, y) = memez_stable::pump(
        &mut memez_fun,
        coin::mint_for_testing(1000 * POW_9, world.scenario.ctx()),
        option::none(),
        option::none(),
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    x.burn_for_testing();
    y.burn_for_testing();

    let sui_coin = memez_stable::dump(
        &mut memez_fun,
        coin::mint_for_testing(POW_9, world.scenario.ctx()),
        option::none(),
        memez_allowed_versions::get_invalid_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    sui_coin.burn_for_testing();

    destroy(memez_fun);
    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ENotBonding, location = memez_fun)]
fun dump_is_not_bonding() {
    let mut world = start();

    let witness = access_control::sign_in_for_testing<MEMEZ>(0);

    world
        .config
        .set_fees<DefaultKey>(
            &witness,
            vector[
                vector[MAX_BPS, 2 * POW_9],
                vector[MAX_BPS, 0, 0],
                vector[MAX_BPS, 0, 0],
                vector[MAX_BPS, 0, TEN_PERCENT],
                vector[MAX_BPS / 2, MAX_BPS / 2, 500],
                vector[VESTING_PERIOD],
            ],
            vector[vector[ADMIN], vector[ADMIN], vector[ADMIN], vector[ADMIN]],
            world.scenario.ctx(),
        );

    let total_supply = POW_9 * POW_9;

    let dev_allocation = POW_9 / 10;

    let stable_config = stable_default_config(total_supply);

    let mut memez_fun = set_up_pool(
        &mut world,
        stable_config,
        vector[dev_allocation, DAY],
    );

    let (x, y) = memez_stable::pump(
        &mut memez_fun,
        coin::mint_for_testing(10_000 * POW_9, world.scenario.ctx()),
        option::none(),
        option::none(),
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    x.burn_for_testing();
    y.burn_for_testing();

    memez_stable::dump(
        &mut memez_fun,
        coin::mint_for_testing(POW_9, world.scenario.ctx()),
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

    let total_supply = POW_9 * POW_9;

    let dev_allocation = POW_9 / 10;

    let stable_config = stable_default_config(total_supply);

    let mut memez_fun = set_up_pool(
        &mut world,
        stable_config,
        vector[dev_allocation, DAY],
    );

    let migrator = memez_stable::migrate(
        &mut memez_fun,
        memez_allowed_versions::get_invalid_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    destroy(migrator);

    destroy(memez_fun);
    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ENotMigrating, location = memez_fun)]
fun migrate_is_not_migrating() {
    let mut world = start();

    let witness = access_control::sign_in_for_testing<MEMEZ>(0);

    world
        .config
        .set_fees<DefaultKey>(
            &witness,
            vector[
                vector[MAX_BPS, 2 * POW_9],
                vector[MAX_BPS, 0, 0],
                vector[MAX_BPS, 0, 0],
                vector[MAX_BPS, 0, TEN_PERCENT],
                vector[MAX_BPS / 2, MAX_BPS / 2, 500],
                vector[VESTING_PERIOD],
            ],
            vector[vector[ADMIN], vector[ADMIN], vector[ADMIN], vector[ADMIN]],
            world.scenario.ctx(),
        );

    let total_supply = POW_9 * POW_9;

    let dev_allocation = POW_9 / 10;

    let stable_config = stable_default_config(total_supply);

    let mut memez_fun = set_up_pool(
        &mut world,
        stable_config,
        vector[dev_allocation, DAY],
    );

    let migrator = memez_stable::migrate(
        &mut memez_fun,
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    destroy(migrator);

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
fun dev_claim_invalid_version() {
    let mut world = start();

    let witness = access_control::sign_in_for_testing<MEMEZ>(0);

    world
        .config
        .set_fees<DefaultKey>(
            &witness,
            vector[
                vector[MAX_BPS, 2 * POW_9],
                vector[MAX_BPS, 0, 0],
                vector[MAX_BPS, 0, 0],
                vector[MAX_BPS, 0, TEN_PERCENT],
                vector[MAX_BPS / 2, MAX_BPS / 2, 500],
                vector[VESTING_PERIOD],
            ],
            vector[vector[ADMIN], vector[ADMIN], vector[ADMIN], vector[ADMIN]],
            world.scenario.ctx(),
        );

    let total_supply = POW_9 * POW_9;

    let dev_allocation = POW_9 / 10;

    let stable_config = stable_default_config(total_supply);

    let mut memez_fun = set_up_pool(
        &mut world,
        stable_config,
        vector[dev_allocation, DAY],
    );

    let (x, y) = memez_stable::pump(
        &mut memez_fun,
        coin::mint_for_testing(10_000 * POW_9, world.scenario.ctx()),
        option::none(),
        option::none(),
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    x.burn_for_testing();
    y.burn_for_testing();

    let migrator = memez_stable::migrate(
        &mut memez_fun,
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    destroy(migrator);

    let clock = clock::create_for_testing(world.scenario.ctx());

    let memez_vesting = memez_stable::dev_allocation_claim(
        &mut memez_fun,
        &clock,
        memez_allowed_versions::get_invalid_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    destroy(clock);
    destroy(memez_vesting);
    destroy(memez_fun);
    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ENotMigrated, location = memez_fun)]
fun dev_claim_has_not_migrated() {
    let mut world = start();

    let total_supply = POW_9 * POW_9;

    let dev_allocation = POW_9 / 10;

    let stable_config = stable_default_config(total_supply);

    let mut memez_fun = set_up_pool(
        &mut world,
        stable_config,
        vector[dev_allocation, DAY],
    );

    let (x, y) = memez_stable::pump(
        &mut memez_fun,
        coin::mint_for_testing(10_000 * POW_9, world.scenario.ctx()),
        option::none(),
        option::none(),
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    x.burn_for_testing();
    y.burn_for_testing();

    let clock = clock::create_for_testing(world.scenario.ctx());

    let memez_vesting = memez_stable::dev_allocation_claim(
        &mut memez_fun,
        &clock,
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    destroy(clock);
    destroy(memez_vesting);
    destroy(memez_fun);
    world.end();
}

#[test, expected_failure(abort_code = memez_errors::EInvalidDev, location = memez_fun)]
fun dev_claim_is_not_dev() {
    let mut world = start();

    let witness = access_control::sign_in_for_testing<MEMEZ>(0);

    world
        .config
        .set_fees<DefaultKey>(
            &witness,
            vector[
                vector[MAX_BPS, 2 * POW_9],
                vector[MAX_BPS, 0, 0],
                vector[MAX_BPS, 0, 0],
                vector[MAX_BPS, 0, TEN_PERCENT],
                vector[MAX_BPS / 2, MAX_BPS / 2, 500],
                vector[VESTING_PERIOD],
            ],
            vector[vector[ADMIN], vector[ADMIN], vector[ADMIN], vector[ADMIN]],
            world.scenario.ctx(),
        );

    let total_supply = POW_9 * POW_9;

    let dev_allocation = POW_9 / 10;

    let stable_config = stable_default_config(total_supply);

    let mut memez_fun = set_up_pool(
        &mut world,
        stable_config,
        vector[dev_allocation, DAY],
    );

    let (x, y) = memez_stable::pump(
        &mut memez_fun,
        coin::mint_for_testing(10_000 * POW_9, world.scenario.ctx()),
        option::none(),
        option::none(),
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    x.burn_for_testing();
    y.burn_for_testing();

    let migrator = memez_stable::migrate(
        &mut memez_fun,
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    destroy(migrator);

    world.scenario.next_tx(@0x6);

    let clock = clock::create_for_testing(world.scenario.ctx());

    let memez_vesting = memez_stable::dev_allocation_claim(
        &mut memez_fun,
        &clock,
        memez_allowed_versions::get_current_allowed_versions_for_testing(),
        world.scenario.ctx(),
    );

    destroy(clock);
    destroy(memez_vesting);
    destroy(memez_fun);
    world.end();
}

fun set_up_pool(
    world: &mut World,
    stable_config: StableConfig,
    dev_payload: vector<u64>,
): MemezFun<Stable, Meme, SUI> {
    let ctx = world.scenario.ctx();

    let (memez_fun, metadata_cap) = memez_stable::new<Meme, SUI, DefaultKey, MigrationWitness>(
        &world.config,
        create_treasury_cap_for_testing(ctx),
        mint_for_testing(2_000_000_000, ctx),
        stable_config,
        memez_metadata::new_for_test(ctx),
        dev_payload,
        vector[STAKE_HOLDER],
        DEV,
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

    scenario.next_tx(ADMIN);

    let mut config = scenario.take_shared<MemezConfig>();

    let witness = access_control::sign_in_for_testing<MEMEZ>(0);

    config.add_migrator_witness<DefaultKey, MigrationWitness>(&witness, scenario.ctx());

    config.add_quote_coin<DefaultKey, SUI>(&witness, scenario.ctx());

    config.set_fees<DefaultKey>(
        &witness,
        vector[
            vector[MAX_BPS, 2 * POW_9],
            vector[MAX_BPS, 0, 0],
            vector[MAX_BPS, 0, 30],
            vector[MAX_BPS, 0, TEN_PERCENT],
            vector[MAX_BPS / 2, MAX_BPS / 2, 0],
            vector[VESTING_PERIOD, VESTING_PERIOD + 1],
        ],
        vector[vector[ADMIN], vector[ADMIN], vector[ADMIN], vector[ADMIN]],
        scenario.ctx(),
    );

    World { config, scenario }
}

fun stable_default_config(total_supply: u64): StableConfig {
    memez_stable_config::new(vector[
        MAX_TARGET_SUI_LIQUIDITY,
        LIQUIDITY_PROVISION,
        MEME_SALE_AMOUNT,
        total_supply,
    ])
}

fun end(world: World) {
    destroy(world);
}
