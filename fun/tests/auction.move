#[test_only]
module memez_fun::memez_auction_tests;

use interest_bps::bps;
use interest_math::u64;
use memez_vesting::memez_vesting::MemezVesting;
use constant_product::constant_product::get_amount_out;
use ipx_coin_standard::ipx_coin_standard::IPXTreasuryStandard;
use memez_acl::acl;
use memez_fun::{
    memez_auction::{Self, Auction},
    memez_config::{Self, MemezConfig, DefaultKey},
    memez_errors,
    memez_fees,
    memez_fun::{Self, MemezFun},
    memez_migrator_list::{Self, MemezMigratorList},
    memez_version
};
use sui::{
    clock::{Self, Clock},
    coin::{mint_for_testing, create_treasury_cap_for_testing, Coin},
    sui::SUI,
    test_scenario::{Self as ts, Scenario},
    test_utils::{assert_eq, destroy},
    token
};

const ADMIN: address = @0x1;

const STAKE_HOLDER: address = @0x2;

// @dev Sui Decimal Scale
const POW_9: u64 = 1__000_000_000;

const MAX_BPS: u64 = 10_000;

const THIRTY_MINUTES_MS: u64 = 30 * 60 * 1_000;

const DEV_ALLOCATION: u64 = 100;
const BURN_TAX: u64 = 2000;
const VIRTUAL_LIQUIDITY: u64 = 1_000 * POW_9;
const TARGET_LIQUIDITY: u64 = 10_000 * POW_9;
const PROVISION_LIQUIDITY: u64 = 500;
const SEED_LIQUIDITY: u64 = 1;

const VESTING_PERIOD: u64 = THIRTY_MINUTES_MS * 10;

const DEV: address = @0x2;

public struct Meme has drop ()

public struct MigrationWitness has drop ()

public struct World {
    config: MemezConfig,
    migrator_list: MemezMigratorList,
    clock: Clock,
    scenario: Scenario,
}

#[test]
fun test_new() {
    let mut world = start();

    let total_supply = 2_500_000_000 * POW_9;

    let start_time = 100;

    world.clock.increment_for_testing(start_time);

    let fees = world.config.fees<DefaultKey>();

    let auction_config = world.config.get_auction<DefaultKey>(total_supply);

    let mut memez_fun = set_up_pool(&mut world, false, total_supply);

    assert_eq(memez_auction::start_time(&mut memez_fun), start_time);

    let expected_allocation_value = bps::new(fees.payloads()[3].payload_value()).calc(total_supply);

    assert_eq(memez_auction::auction_duration(&mut memez_fun), THIRTY_MINUTES_MS);
    assert_eq(
        memez_auction::initial_reserve(&mut memez_fun),
        total_supply - expected_allocation_value - auction_config[4] - auction_config[5],
    );
    assert_eq(
        memez_auction::meme_reserve(&mut memez_fun),
        total_supply - expected_allocation_value - auction_config[4] - auction_config[5],
    );
    assert_eq(memez_auction::allocation(&mut memez_fun).value(), expected_allocation_value);
    assert_eq(memez_auction::liquidity_provision(&mut memez_fun), auction_config[4]);

    let cp = memez_auction::constant_product(&mut memez_fun);

    assert_eq(cp.virtual_liquidity(), auction_config[2]);
    assert_eq(cp.target_sui_liquidity(), auction_config[3]);
    assert_eq(cp.burner().fee().value(), auction_config[1]);
    assert_eq(cp.meme_balance().value(), auction_config[5]);
    assert_eq(cp.sui_balance().value(), 0);

    memez_fun.assert_is_bonding();
    memez_fun.assert_uses_coin();

    destroy(memez_fun);

    world.end();
}

#[test]
fun test_new_token() {
    let mut world = start();

    let total_supply = 2_500_000_000 * POW_9;

    let start_time = 100;

    world.clock.increment_for_testing(start_time);

    let fees = world.config.fees<DefaultKey>();

    let auction_config = world.config.get_auction<DefaultKey>(total_supply);

    let mut memez_fun = set_up_pool(&mut world, true, total_supply);

    assert_eq(memez_auction::start_time(&mut memez_fun), start_time);

    let expected_allocation_value = bps::new(fees.payloads()[3].payload_value()).calc(total_supply);

    assert_eq(memez_auction::auction_duration(&mut memez_fun), THIRTY_MINUTES_MS);
    assert_eq(
        memez_auction::initial_reserve(&mut memez_fun),
        total_supply - expected_allocation_value - auction_config[4] - auction_config[5],
    );
    assert_eq(
        memez_auction::meme_reserve(&mut memez_fun),
        total_supply - expected_allocation_value - auction_config[4] - auction_config[5],
    );
    assert_eq(memez_auction::allocation(&mut memez_fun).value(), expected_allocation_value);
    assert_eq(memez_auction::liquidity_provision(&mut memez_fun), auction_config[4]);

    let cp = memez_auction::constant_product(&mut memez_fun);

    assert_eq(cp.virtual_liquidity(), auction_config[2]);
    assert_eq(cp.target_sui_liquidity(), auction_config[3]);
    assert_eq(cp.burner().fee().value(), auction_config[1]);
    assert_eq(cp.meme_balance().value(), auction_config[5]);
    assert_eq(cp.sui_balance().value(), 0);

    memez_fun.assert_is_bonding();
    memez_fun.assert_uses_token();

    destroy(memez_fun);

    world.end();
}

#[test]
fun test_decrease_auction_mechanism() {
    let mut world = start();

    let total_supply = 1_000_000_000 * POW_9;

    let start_time = 100;

    world.clock.increment_for_testing(start_time);

    let mut memez_fun = set_up_pool(&mut world, false, total_supply);

    let meme_balance_t0 = memez_auction::constant_product(&mut memez_fun).meme_balance().value();

    let market_cap_t0 = memez_auction::market_cap(&mut memez_fun, &world.clock, 9, total_supply);

    assert_eq(market_cap_t0 > 7_500_000 * POW_9, true);

    let final_meme_balance = memez_auction::initial_reserve(&mut memez_fun);

    world.clock.increment_for_testing(THIRTY_MINUTES_MS / 2);

    let market_cap_t1 = memez_auction::market_cap(&mut memez_fun, &world.clock, 9, total_supply);

    assert_eq(
        memez_auction::current_meme_balance(&mut memez_fun, &world.clock),
        final_meme_balance / 2 + meme_balance_t0,
    );

    // @dev After 15 minutes the market is lower than 2000 Sui
    assert_eq(2500 * POW_9 > market_cap_t1, true);
    assert_eq(1500 * POW_9 < market_cap_t1, true);

    world.clock.increment_for_testing(THIRTY_MINUTES_MS / 2);

    let market_cap_t2 = memez_auction::market_cap(&mut memez_fun, &world.clock, 9, total_supply);

    assert_eq(
        memez_auction::current_meme_balance(&mut memez_fun, &world.clock),
        final_meme_balance + meme_balance_t0,
    );

    // @dev After 30 minutes the market is lower than 1000 Sui
    assert_eq(1100 * POW_9 > market_cap_t2, true);

    destroy(memez_fun);

    world.end();
}

#[test]
fun test_coin_end_to_end() {
    let mut world = start();

    let total_supply = 1_000_000_000 * POW_9;

    let start_time = 100;

    world.clock.increment_for_testing(start_time);

    let mut memez_fun = set_up_pool(&mut world, false, total_supply);

    world.scenario.next_tx(ADMIN);

    let creation_fee = world.scenario.take_from_address<Coin<SUI>>(ADMIN);

    assert_eq(creation_fee.burn_for_testing(), 2 * POW_9);

    let cp = memez_auction::constant_product(&mut memez_fun);

    let initial_meme_balance = cp.meme_balance().value();

    let swap_fee = cp.swap_fee().calculate(1_000 * POW_9);

    let expected_meme_amount_out = get_amount_out(
        1_000 * POW_9 - swap_fee,
        cp.virtual_liquidity(),
        cp.meme_balance().value(),
    );

    let meme_coin = memez_auction::pump(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(1_000 * POW_9, world.scenario.ctx()),
        expected_meme_amount_out,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    assert_eq(meme_coin.burn_for_testing(), expected_meme_amount_out);

    let cp = memez_auction::constant_product(&mut memez_fun);

    assert_eq(cp.sui_balance().value(), 1_000 * POW_9 - swap_fee);
    assert_eq(cp.meme_balance().value(), initial_meme_balance - expected_meme_amount_out);

    memez_fun.assert_is_bonding();
    memez_fun.assert_uses_coin();

    // @dev Advance 5 minutes to increase liquidity
    world.clock.increment_for_testing(THIRTY_MINUTES_MS / 6);

    let current_meme_balance = memez_auction::current_meme_balance(&mut memez_fun, &world.clock);

    let cp = memez_auction::constant_product(&mut memez_fun);

    let expected_meme_amount_out_2 = get_amount_out(
        1_000 * POW_9 - swap_fee,
        cp.virtual_liquidity() + cp.sui_balance().value(),
        current_meme_balance,
    );

    // Get at cheaper value
    assert_eq(expected_meme_amount_out_2 > expected_meme_amount_out, true);

    let meme_coin_2 = memez_auction::pump(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(1_000 * POW_9, world.scenario.ctx()),
        expected_meme_amount_out_2,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    assert_eq(meme_coin_2.burn_for_testing(), expected_meme_amount_out_2);

    let cp = memez_auction::constant_product(&mut memez_fun);

    let amounts = cp.dump_amount(expected_meme_amount_out_2 / 2, 0);

    let mut treasury = world.scenario.take_shared<IPXTreasuryStandard>();

    let sui_coin = memez_auction::dump(
        &mut memez_fun,
        &world.clock,
        &mut treasury,
        mint_for_testing(expected_meme_amount_out_2 / 2, world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    assert_eq(sui_coin.burn_for_testing(), amounts[1]);

    let cp = memez_auction::constant_product(&mut memez_fun);

    let remaining_amount_to_migrate = 10_000 * POW_9 - cp.sui_balance().value();

    let expected_meme_amount_out = get_amount_out(
        remaining_amount_to_migrate,
        cp.virtual_liquidity() + cp.sui_balance().value(),
        cp.meme_balance().value(),
    );

    let meme_coin = memez_auction::pump(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(
            remaining_amount_to_migrate * 10_000 / (10_000 - 30),
            world.scenario.ctx(),
        ),
        expected_meme_amount_out,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    assert_eq(meme_coin.burn_for_testing(), expected_meme_amount_out);

    memez_fun.assert_is_migrating();

    let migrator = memez_auction::migrate(
        &mut memez_fun,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    let (sui_balance, meme_balance) = migrator.destroy(MigrationWitness());

    let auction_config = world.config.get_auction<DefaultKey>(total_supply);

    assert_eq(sui_balance.value(), 10_000 * POW_9 - 200 * POW_9);
    assert_eq(meme_balance.value(), auction_config[4]);

    sui_balance.destroy_for_testing();
    meme_balance.destroy_for_testing();

    memez_fun.assert_migrated();

    world.scenario.next_tx(DEV);

    let migration_fee = world.scenario.take_from_address<Coin<SUI>>(ADMIN);

    assert_eq(migration_fee.burn_for_testing(), 200 * POW_9);

    memez_auction::distribute_stake_holders_allocation(&mut memez_fun, &world.clock, memez_version::get_version_for_testing(1), world.scenario.ctx());

    world.scenario.next_tx(DEV);

    let dev_allocation = world.scenario.take_from_address<MemezVesting<Meme>>(DEV);

    let fees = world.config.fees<DefaultKey>();

    let expected_allocation_value = bps::new(fees.payloads()[3].payload_value()).calc(total_supply);

    assert_eq(dev_allocation.balance(), expected_allocation_value);

    destroy(memez_fun);
    destroy(dev_allocation);

    destroy(treasury);
    world.end();
}

#[test]
fun test_token_end_to_end() {
    let mut world = start();

    let total_supply = 1_000_000_000 * POW_9;

    let start_time = 100;

    world.clock.increment_for_testing(start_time);

    let mut memez_fun = set_up_pool(&mut world, true, total_supply);

    world.scenario.next_tx(ADMIN);

    let creation_fee = world.scenario.take_from_address<Coin<SUI>>(ADMIN);

    assert_eq(creation_fee.burn_for_testing(), 2 * POW_9);

    let cp = memez_auction::constant_product(&mut memez_fun);

    let initial_meme_balance = cp.meme_balance().value();

    let swap_fee = cp.swap_fee().calculate(1_000 * POW_9);

    let expected_meme_amount_out = get_amount_out(
        1_000 * POW_9 - swap_fee,
        cp.virtual_liquidity(),
        cp.meme_balance().value(),
    );

    let meme_token = memez_auction::pump_token(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(1_000 * POW_9, world.scenario.ctx()),
        expected_meme_amount_out,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    assert_eq(meme_token.value(), expected_meme_amount_out);

    meme_token.burn_for_testing();

    let cp = memez_auction::constant_product(&mut memez_fun);

    assert_eq(cp.sui_balance().value(), 1_000 * POW_9 - swap_fee);
    assert_eq(cp.meme_balance().value(), initial_meme_balance - expected_meme_amount_out);

    memez_fun.assert_is_bonding();
    memez_fun.assert_uses_token();

    // @dev Advance 5 minutes to increase liquidity
    world.clock.increment_for_testing(THIRTY_MINUTES_MS / 6);

    let current_meme_balance = memez_auction::current_meme_balance(&mut memez_fun, &world.clock);

    let cp = memez_auction::constant_product(&mut memez_fun);

    let expected_meme_amount_out_2 = get_amount_out(
        1_000 * POW_9 - swap_fee,
        cp.virtual_liquidity() + cp.sui_balance().value(),
        current_meme_balance,
    );

    // Get at cheaper value
    assert_eq(expected_meme_amount_out_2 > expected_meme_amount_out, true);

    let meme_token_2 = memez_auction::pump_token(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(1_000 * POW_9, world.scenario.ctx()),
        expected_meme_amount_out_2,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    assert_eq(meme_token_2.value(), expected_meme_amount_out_2);

    meme_token_2.burn_for_testing();

    let cp = memez_auction::constant_product(&mut memez_fun);

    let amounts = cp.dump_amount(expected_meme_amount_out_2 / 2, 0);

    let mut treasury = world.scenario.take_shared<IPXTreasuryStandard>();

    let sui_coin = memez_auction::dump_token(
        &mut memez_fun,
        &world.clock,
        &mut treasury,
        token::mint_for_testing(expected_meme_amount_out_2 / 2, world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    assert_eq(sui_coin.burn_for_testing(), amounts[1]);

    let cp = memez_auction::constant_product(&mut memez_fun);

    let remaining_amount_to_migrate = 10_000 * POW_9 - cp.sui_balance().value();

    let expected_meme_amount_out = get_amount_out(
        remaining_amount_to_migrate,
        cp.virtual_liquidity() + cp.sui_balance().value(),
        cp.meme_balance().value(),
    );

    let meme_token = memez_auction::pump_token(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(
            remaining_amount_to_migrate * 10_000 / (10_000 - 30),
            world.scenario.ctx(),
        ),
        expected_meme_amount_out,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    assert_eq(meme_token.value(), expected_meme_amount_out);

    memez_fun.assert_is_migrating();

    let migrator = memez_auction::migrate(
        &mut memez_fun,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    let (sui_balance, meme_balance) = migrator.destroy(MigrationWitness());

    let auction_config = world.config.get_auction<DefaultKey>(total_supply);

    assert_eq(sui_balance.value(), 10_000 * POW_9 - 200 * POW_9);
    assert_eq(meme_balance.value(), auction_config[4]);

    sui_balance.destroy_for_testing();
    meme_balance.destroy_for_testing();

    memez_fun.assert_migrated();

    world.scenario.next_tx(DEV);

    let migration_fee = world.scenario.take_from_address<Coin<SUI>>(ADMIN);

    assert_eq(migration_fee.burn_for_testing(), 200 * POW_9);

    memez_auction::distribute_stake_holders_allocation(&mut memez_fun, &world.clock, memez_version::get_version_for_testing(1), world.scenario.ctx());

    world.scenario.next_tx(DEV);

    let dev_allocation = world.scenario.take_from_address<MemezVesting<Meme>>(DEV);

    let fees = world.config.fees<DefaultKey>();

    let expected_allocation_value = bps::new(fees.payloads()[3].payload_value()).calc(total_supply);

    assert_eq(dev_allocation.balance(), expected_allocation_value);


    let meme_coin = memez_auction::to_coin(
        &mut memez_fun,
        meme_token,
        world.scenario.ctx(),
    );

    assert_eq(meme_coin.burn_for_testing(), expected_meme_amount_out);

    destroy(memez_fun);

    destroy(treasury);
    destroy(dev_allocation);

    world.end();
}

#[test]
fun test_coin_end_to_end_with_stake_holders() {
    let mut world = start();

    let witness = acl::sign_in_for_testing();

    world.config.set_fees<DefaultKey>(
        &witness,
        vector[vector[MAX_BPS / 2, MAX_BPS / 2,  2 * POW_9], vector[3_000, 7_000, 30], vector[2_000, 8_000, 200 * POW_9], vector[0, MAX_BPS, VESTING_PERIOD, 500]],
        vector[vector[ADMIN, STAKE_HOLDER], vector[ADMIN], vector[ADMIN], vector[ADMIN]],
        world.scenario.ctx(),
    );

    world.config.set_auction<DefaultKey>(
        &witness,
        vector[
            THIRTY_MINUTES_MS,
            BURN_TAX,
            VIRTUAL_LIQUIDITY,
            TARGET_LIQUIDITY,
            PROVISION_LIQUIDITY,
            SEED_LIQUIDITY,
        ],
        world.scenario.ctx(),
    );

    let total_supply = 1_000_000_000 * POW_9;

    let start_time = 100;

    world.clock.increment_for_testing(start_time);

    let metadata_cap = memez_auction::new<Meme, DefaultKey, MigrationWitness>(
        &world.config,
        &world.migrator_list,
        &world.clock,
        create_treasury_cap_for_testing(world.scenario.ctx()),
        mint_for_testing(2_000_000_000, world.scenario.ctx()),
        total_supply,
        false,
        vector[],
        vector[],
        vector[STAKE_HOLDER],
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    destroy(metadata_cap);

    world.scenario.next_tx(ADMIN);

    let mut memez_fun = world.scenario.take_shared<MemezFun<Auction, Meme>>();

    world.scenario.next_tx(ADMIN);

    // 50% of the creation fee is paid to the admin
    assert_eq(world.scenario.take_from_address<Coin<SUI>>(ADMIN).burn_for_testing(), POW_9);

    // 50% of the creation fee is paid to the stake holder
    assert_eq(world.scenario.take_from_address<Coin<SUI>>(STAKE_HOLDER).burn_for_testing(), POW_9);

    let cp = memez_auction::constant_product(&mut memez_fun);

    let initial_meme_balance = cp.meme_balance().value();

    let swap_fee = cp.swap_fee().calculate(1_000 * POW_9);

    let expected_meme_amount_out = get_amount_out(
        1_000 * POW_9 - swap_fee,
        cp.virtual_liquidity(),
        cp.meme_balance().value(),
    );

    let meme_coin = memez_auction::pump(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(1_000 * POW_9, world.scenario.ctx()),
        expected_meme_amount_out,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    assert_eq(meme_coin.burn_for_testing(), expected_meme_amount_out);

    world.scenario.next_tx(ADMIN);

    // 70% of the swap fee is paid to the admin
    assert_eq(world.scenario.take_from_address<Coin<SUI>>(ADMIN).burn_for_testing(), swap_fee * 3_000 / 10_000);

    // 30% of the swap fee is paid to the stake holder
    assert_eq(world.scenario.take_from_address<Coin<SUI>>(STAKE_HOLDER).burn_for_testing(), swap_fee * 7_000 / 10_000);

    let cp = memez_auction::constant_product(&mut memez_fun);

    assert_eq(cp.sui_balance().value(), 1_000 * POW_9 - swap_fee);
    assert_eq(cp.meme_balance().value(), initial_meme_balance - expected_meme_amount_out);

    memez_fun.assert_is_bonding();
    memez_fun.assert_uses_coin();

    // @dev Advance 5 minutes to increase liquidity
    world.clock.increment_for_testing(THIRTY_MINUTES_MS / 6);

    let current_meme_balance = memez_auction::current_meme_balance(&mut memez_fun, &world.clock);

    let cp = memez_auction::constant_product(&mut memez_fun);

    let expected_meme_amount_out_2 = get_amount_out(
        1_000 * POW_9 - swap_fee,
        cp.virtual_liquidity() + cp.sui_balance().value(),
        current_meme_balance,
    );

    // Get at cheaper value
    assert_eq(expected_meme_amount_out_2 > expected_meme_amount_out, true);

    let meme_coin_2 = memez_auction::pump(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(1_000 * POW_9, world.scenario.ctx()),
        expected_meme_amount_out_2,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    assert_eq(meme_coin_2.burn_for_testing(), expected_meme_amount_out_2);

    let cp = memez_auction::constant_product(&mut memez_fun);

    let amounts = cp.dump_amount(expected_meme_amount_out_2 / 2, 0);

    let mut treasury = world.scenario.take_shared<IPXTreasuryStandard>();

    let sui_coin = memez_auction::dump(
        &mut memez_fun,
        &world.clock,
        &mut treasury,
        mint_for_testing(expected_meme_amount_out_2 / 2, world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    assert_eq(sui_coin.burn_for_testing(), amounts[1]);

    let cp = memez_auction::constant_product(&mut memez_fun);

    let remaining_amount_to_migrate = 10_000 * POW_9 - cp.sui_balance().value();

    let expected_meme_amount_out = get_amount_out(
        remaining_amount_to_migrate,
        cp.virtual_liquidity() + cp.sui_balance().value(),
        cp.meme_balance().value(),
    );

    let meme_coin = memez_auction::pump(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(
            remaining_amount_to_migrate * 10_000 / (10_000 - 30),
            world.scenario.ctx(),
        ),
        expected_meme_amount_out,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    assert_eq(meme_coin.burn_for_testing(), expected_meme_amount_out);

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
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    let (sui_balance, meme_balance) = migrator.destroy(MigrationWitness());

    let auction_config = world.config.get_auction<DefaultKey>(total_supply);

    assert_eq(sui_balance.value(), 10_000 * POW_9 - 200 * POW_9);
    assert_eq(meme_balance.value(), auction_config[4]);

    sui_balance.destroy_for_testing();
    meme_balance.destroy_for_testing();

    memez_fun.assert_migrated();

    world.scenario.next_tx(DEV);

    assert_eq(world.scenario.take_from_address<Coin<SUI>>(ADMIN).burn_for_testing(), 200 * POW_9 * 2_000 / 10_000);
    assert_eq(world.scenario.take_from_address<Coin<SUI>>(STAKE_HOLDER).burn_for_testing(), 200 * POW_9 * 8_000 / 10_000);

    memez_auction::distribute_stake_holders_allocation(
        &mut memez_fun,
        &world.clock,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    world.scenario.next_tx(DEV); 

    let vested_meme_coin = world.scenario.take_from_address<MemezVesting<Meme>>(STAKE_HOLDER);

    assert_eq(vested_meme_coin.balance(), u64::mul_div_down(total_supply, 500, 10_000));
    assert_eq(vested_meme_coin.duration(), VESTING_PERIOD);

    destroy(memez_fun);

    destroy(treasury);
    destroy(vested_meme_coin);
    world.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EOutdatedPackageVersion,
        location = memez_version,
    ),
]
fun new_invalid_version() {
    let mut world = start();

    let metadata_cap = memez_auction::new<Meme, DefaultKey, MigrationWitness>(
        &world.config,
        &world.migrator_list,
        &world.clock,
        create_treasury_cap_for_testing(world.scenario.ctx()),
        mint_for_testing(2_000_000_000, world.scenario.ctx()),
        1_000_000_000 * POW_9,
        true,
        vector[],
        vector[],
        vector[],
        memez_version::get_version_for_testing(2),
        world.scenario.ctx(),
    );

    destroy(metadata_cap);

    world.end();
}

#[test, expected_failure(abort_code = memez_errors::EInsufficientValue, location = memez_fees)]
fun new_low_creation_fee() {
    let mut world = start();

    let metadata_cap = memez_auction::new<Meme, DefaultKey, MigrationWitness>(
        &world.config,
        &world.migrator_list,
        &world.clock,
        create_treasury_cap_for_testing(world.scenario.ctx()),
        mint_for_testing(2_000_000_000 - 1, world.scenario.ctx()),
        1_000_000_000 * POW_9,
        true,
        vector[],
        vector[],
        vector[],
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    destroy(metadata_cap);

    world.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EOutdatedPackageVersion,
        location = memez_version,
    ),
]
fun pump_invalid_version() {
    let mut world = start();

    let mut memez_fun = set_up_pool(&mut world, false, 1_000_000_000 * POW_9);

    memez_auction::pump(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(1_000 * POW_9, world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(2),
        world.scenario.ctx(),
    ).burn_for_testing();

    destroy(memez_fun);
    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ETokenSupported, location = memez_fun)]
fun pump_use_token_instead() {
    let mut world = start();

    let mut memez_fun = set_up_pool(&mut world, true, 1_000_000_000 * POW_9);

    memez_auction::pump(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(1_000 * POW_9, world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    ).burn_for_testing();

    destroy(memez_fun);
    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ENotBonding, location = memez_fun)]
fun pump_is_not_bonding() {
    let mut world = start();

    let mut memez_fun = set_up_pool(&mut world, false, 1_000_000_000 * POW_9);

    memez_auction::pump(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(10_000 * POW_9 * 10_000 / (10_000 - 30), world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    ).burn_for_testing();

    memez_auction::pump(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(10_000 * POW_9, world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    ).burn_for_testing();

    destroy(memez_fun);
    world.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EOutdatedPackageVersion,
        location = memez_version,
    ),
]
fun dump_invalid_version() {
    let mut world = start();

    let mut memez_fun = set_up_pool(&mut world, false, 1_000_000_000 * POW_9);

    let mut treasury = world.scenario.take_shared<IPXTreasuryStandard>();

    memez_auction::dump(
        &mut memez_fun,
        &world.clock,
        &mut treasury,
        mint_for_testing(POW_9, world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(2),
        world.scenario.ctx(),
    ).burn_for_testing();

    destroy(treasury);
    destroy(memez_fun);
    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ETokenSupported, location = memez_fun)]
fun dump_use_token_instead() {
    let mut world = start();

    let mut memez_fun = set_up_pool(&mut world, true, 1_000_000_000 * POW_9);

    let mut treasury = world.scenario.take_shared<IPXTreasuryStandard>();

    memez_auction::dump(
        &mut memez_fun,
        &world.clock,
        &mut treasury,
        mint_for_testing(POW_9, world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    ).burn_for_testing();

    destroy(treasury);
    destroy(memez_fun);
    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ENotBonding, location = memez_fun)]
fun dump_is_not_bonding() {
    let mut world = start();

    let mut memez_fun = set_up_pool(&mut world, false, 1_000_000_000 * POW_9);

    let mut treasury = world.scenario.take_shared<IPXTreasuryStandard>();

    memez_auction::pump(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(10_000 * POW_9 * 10_000 / (10_000 - 30), world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    ).burn_for_testing();

    memez_auction::dump(
        &mut memez_fun,
        &world.clock,
        &mut treasury,
        mint_for_testing(POW_9, world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    ).burn_for_testing();

    destroy(treasury);
    destroy(memez_fun);
    world.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EOutdatedPackageVersion,
        location = memez_version,
    ),
]
fun migrate_invalid_version() {
    let mut world = start();

    let mut memez_fun = set_up_pool(&mut world, false, 1_000_000_000 * POW_9);

    let migrator = memez_auction::migrate(
        &mut memez_fun,
        memez_version::get_version_for_testing(2),
        world.scenario.ctx(),
    );

    destroy(migrator);

    abort
}

#[test, expected_failure(abort_code = memez_errors::ENotMigrating, location = memez_fun)]
fun migrate_is_not_migrating() {
    let mut world = start();

    let mut memez_fun = set_up_pool(&mut world, false, 1_000_000_000 * POW_9);

    let migrator = memez_auction::migrate(
        &mut memez_fun,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    destroy(migrator);

    abort
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EOutdatedPackageVersion,
        location = memez_version,
    ),
]
fun pump_token_invalid_version() {
    let mut world = start();

    let mut memez_fun = set_up_pool(&mut world, true, 1_000_000_000 * POW_9);

    memez_auction::pump_token(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(1_000 * POW_9, world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(2),
        world.scenario.ctx(),
    ).burn_for_testing();

    destroy(memez_fun);
    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ETokenNotSupported, location = memez_fun)]
fun pump_token_use_coin_instead() {
    let mut world = start();

    let mut memez_fun = set_up_pool(&mut world, false, 1_000_000_000 * POW_9);

    memez_auction::pump_token(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(1_000 * POW_9, world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    ).burn_for_testing();

    destroy(memez_fun);
    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ENotBonding, location = memez_fun)]
fun pump_token_is_not_bonding() {
    let mut world = start();

    let mut memez_fun = set_up_pool(&mut world, true, 1_000_000_000 * POW_9);

    memez_auction::pump_token(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(10_000 * POW_9 * 10_000 / (10_000 - 30), world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    ).burn_for_testing();

    memez_auction::pump_token(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(POW_9, world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    ).burn_for_testing();

    destroy(memez_fun);
    world.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EOutdatedPackageVersion,
        location = memez_version,
    ),
]
fun dump_token_invalid_version() {
    let mut world = start();

    let mut memez_fun = set_up_pool(&mut world, true, 1_000_000_000 * POW_9);

    let mut treasury = world.scenario.take_shared<IPXTreasuryStandard>();

    memez_auction::dump_token(
        &mut memez_fun,
        &world.clock,
        &mut treasury,
        token::mint_for_testing(POW_9, world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(2),
        world.scenario.ctx(),
    ).burn_for_testing();

    destroy(treasury);
    destroy(memez_fun);
    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ETokenNotSupported, location = memez_fun)]
fun dump_token_use_coin_instead() {
    let mut world = start();

    let mut memez_fun = set_up_pool(&mut world, false, 1_000_000_000 * POW_9);

    let mut treasury = world.scenario.take_shared<IPXTreasuryStandard>();

    memez_auction::dump_token(
        &mut memez_fun,
        &world.clock,
        &mut treasury,
        token::mint_for_testing(POW_9, world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    ).burn_for_testing();

    destroy(treasury);
    destroy(memez_fun);
    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ENotBonding, location = memez_fun)]
fun dump_token_is_not_bonding() {
    let mut world = start();

    let mut memez_fun = set_up_pool(&mut world, true, 1_000_000_000 * POW_9);

    let mut treasury = world.scenario.take_shared<IPXTreasuryStandard>();

    memez_auction::pump_token(
        &mut memez_fun,
        &world.clock,
        mint_for_testing(10_000 * POW_9 * 10_000 / (10_000 - 30), world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    ).burn_for_testing();

    memez_auction::dump_token(
        &mut memez_fun,
        &world.clock,
        &mut treasury,
        token::mint_for_testing(POW_9, world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    ).burn_for_testing();

    destroy(treasury);
    destroy(memez_fun);
    world.end();
}

fun set_up_pool(world: &mut World, is_token: bool, total_supply: u64): MemezFun<Auction, Meme> {
    let ctx = world.scenario.ctx();

    let metadata_cap = memez_auction::new<Meme, DefaultKey, MigrationWitness>(
        &world.config,
        &world.migrator_list,
        &world.clock,
        create_treasury_cap_for_testing(ctx),
        mint_for_testing(2_000_000_000, ctx),
        total_supply,
        is_token,
        vector[],
        vector[],
        vector[],
        memez_version::get_version_for_testing(1),
        ctx,
    );

    destroy(metadata_cap);

    world.scenario.next_tx(ADMIN);

    world.scenario.take_shared<MemezFun<Auction, Meme>>()
}

fun start(): World {
    let mut scenario = ts::begin(ADMIN);

    memez_config::init_for_testing(scenario.ctx());
    memez_migrator_list::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let mut config = scenario.take_shared<MemezConfig>();
    let mut migrator_list = scenario.take_shared<MemezMigratorList>();

    let witness = acl::sign_in_for_testing();

    migrator_list.add<MigrationWitness>(&witness);

    let witness = acl::sign_in_for_testing();

    config.set_fees<DefaultKey>(
        &witness,
        vector[vector[MAX_BPS, 2 * POW_9], vector[MAX_BPS, 30], vector[MAX_BPS, 200 * POW_9], vector[MAX_BPS, VESTING_PERIOD, DEV_ALLOCATION]],
        vector[vector[ADMIN], vector[ADMIN], vector[ADMIN], vector[DEV]],
        scenario.ctx(),
    );

    config.set_auction<DefaultKey>(
        &witness,
        vector[
            THIRTY_MINUTES_MS,
            BURN_TAX,
            VIRTUAL_LIQUIDITY,
            TARGET_LIQUIDITY,
            PROVISION_LIQUIDITY,
            SEED_LIQUIDITY,
        ],
        scenario.ctx(),
    );

    let clock = clock::create_for_testing(scenario.ctx());

    World { config, migrator_list, clock, scenario }
}

fun end(world: World) {
    destroy(world);
}