#[test_only]
module memez_fun::memez_auction_tests;

use constant_product::constant_product::get_amount_out;
use interest_math::u64;
use ipx_coin_standard::ipx_coin_standard::IPXTreasuryStandard;
use memez_acl::acl;
use memez_fun::{
    memez_auction::{Self, Auction},
    memez_auction_config,
    memez_config::{Self, MemezConfig},
    memez_errors,
    memez_fun::{Self, MemezFun},
    memez_migrator_list::{Self, MemezMigratorList},
    memez_version
};
use sui::{
    balance,
    clock::{Self, Clock},
    coin::{Self, mint_for_testing, create_treasury_cap_for_testing, Coin},
    sui::SUI,
    test_scenario::{Self as ts, Scenario},
    test_utils::{assert_eq, destroy},
    token
};

const ADMIN: address = @0x1;

// @dev Sui Decimal Scale
const POW_9: u64 = 1__000_000_000;

const THIRTY_MINUTES_MS: u64 = 30 * 60 * 1_000;

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

    let auction_config = memez_auction_config::get(&world.config, total_supply);

    let mut memez_fun = set_up_pool(&mut world, false, total_supply);

    assert_eq(memez_auction::start_time(&mut memez_fun), start_time);

    assert_eq(memez_auction::auction_duration(&mut memez_fun), THIRTY_MINUTES_MS);
    assert_eq(
        memez_auction::initial_reserve(&mut memez_fun),
        total_supply - auction_config[1] - auction_config[5] - auction_config[6],
    );
    assert_eq(
        memez_auction::meme_reserve(&mut memez_fun),
        total_supply - auction_config[1] - auction_config[5] - auction_config[6],
    );
    assert_eq(memez_auction::dev_allocation(&mut memez_fun), auction_config[1]);
    assert_eq(memez_auction::liquidity_provision(&mut memez_fun), auction_config[5]);

    let cp = memez_auction::constant_product(&mut memez_fun);

    assert_eq(cp.virtual_liquidity(), auction_config[3]);
    assert_eq(cp.target_sui_liquidity(), auction_config[4]);
    assert_eq(cp.burn_tax().value(), auction_config[2]);
    assert_eq(cp.meme_balance().value(), auction_config[6]);
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

    let auction_config = memez_auction_config::get(&world.config, total_supply);

    let mut memez_fun = set_up_pool(&mut world, true, total_supply);

    assert_eq(memez_auction::start_time(&mut memez_fun), start_time);

    assert_eq(memez_auction::auction_duration(&mut memez_fun), THIRTY_MINUTES_MS);
    assert_eq(
        memez_auction::initial_reserve(&mut memez_fun),
        total_supply - auction_config[1] - auction_config[5] - auction_config[6],
    );
    assert_eq(
        memez_auction::meme_reserve(&mut memez_fun),
        total_supply - auction_config[1] - auction_config[5] - auction_config[6],
    );
    assert_eq(memez_auction::dev_allocation(&mut memez_fun), auction_config[1]);
    assert_eq(memez_auction::liquidity_provision(&mut memez_fun), auction_config[5]);

    let cp = memez_auction::constant_product(&mut memez_fun);

    assert_eq(cp.virtual_liquidity(), auction_config[3]);
    assert_eq(cp.target_sui_liquidity(), auction_config[4]);
    assert_eq(cp.burn_tax().value(), auction_config[2]);
    assert_eq(cp.meme_balance().value(), auction_config[6]);
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
    assert_eq(2000 * POW_9 > market_cap_t1, true);
    assert_eq(1500 * POW_9 < market_cap_t1, true);

    world.clock.increment_for_testing(THIRTY_MINUTES_MS / 2);

    let market_cap_t2 = memez_auction::market_cap(&mut memez_fun, &world.clock, 9, total_supply);

    assert_eq(
        memez_auction::current_meme_balance(&mut memez_fun, &world.clock),
        final_meme_balance + meme_balance_t0,
    );

    // @dev After 30 minutes the market is lower than 1000 Sui
    assert_eq(1000 * POW_9 > market_cap_t2, true);

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

    let creation_fee = world.scenario.take_from_address<Coin<SUI>>(@treasury);

    assert_eq(creation_fee.burn_for_testing(), 2 * POW_9);

    let cp = memez_auction::constant_product(&mut memez_fun);

    let initial_meme_balance = cp.meme_balance().value();

    let expected_meme_amount_out = get_amount_out(
        1_000 * POW_9,
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

    assert_eq(cp.sui_balance().value(), 1_000 * POW_9);
    assert_eq(cp.meme_balance().value(), initial_meme_balance - expected_meme_amount_out);

    memez_fun.assert_is_bonding();
    memez_fun.assert_uses_coin();

    // @dev Advance 5 minutes to increase liquidity 
    world.clock.increment_for_testing(THIRTY_MINUTES_MS / 6);

    let current_meme_balance = memez_auction::current_meme_balance(&mut memez_fun, &world.clock);

    let cp = memez_auction::constant_product(&mut memez_fun);

    let expected_meme_amount_out_2 = get_amount_out(
        1_000 * POW_9,
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

    let (_, expected_sui_value, _) = cp.dump_amount(expected_meme_amount_out_2 / 2, 0);

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

    assert_eq(sui_coin.burn_for_testing(), expected_sui_value);

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
        mint_for_testing(remaining_amount_to_migrate, world.scenario.ctx()),
        expected_meme_amount_out,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    assert_eq(meme_coin.burn_for_testing(), expected_meme_amount_out);

    memez_fun.assert_is_migrating();

    let migrator = memez_auction::migrate(
        &mut memez_fun,
        &world.config,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    let (sui_balance, meme_balance) = migrator.destroy(MigrationWitness());

    let auction_config = memez_auction_config::get(&world.config, total_supply);

    assert_eq(sui_balance.value(), 10_000 * POW_9 - 200 * POW_9);
    assert_eq(meme_balance.value(), auction_config[5]);

    sui_balance.destroy_for_testing();
    meme_balance.destroy_for_testing();

    memez_fun.assert_migrated();

    world.scenario.next_tx(ADMIN);

    let migration_fee = world.scenario.take_from_address<Coin<SUI>>(@treasury);

    assert_eq(migration_fee.burn_for_testing(), 200 * POW_9);

    let dev_allocation = memez_auction::dev_claim(&mut memez_fun, memez_version::get_version_for_testing(1), world.scenario.ctx());

    assert_eq(dev_allocation.burn_for_testing(), auction_config[1]);

    destroy(memez_fun);

    destroy(treasury);
    world.end();
}

fun set_up_pool(world: &mut World, is_token: bool, total_supply: u64): MemezFun<Auction, Meme> {
    let ctx = world.scenario.ctx();

    let metadata_cap = memez_auction::new<Meme, MigrationWitness>(
        &world.config,
        &world.migrator_list,
        &world.clock,
        create_treasury_cap_for_testing(ctx),
        mint_for_testing(2_000_000_000, ctx),
        total_supply,
        is_token,
        vector[],
        vector[],
        memez_version::get_version_for_testing(1),
        ctx,
    );

    metadata_cap.destroy();

    world.scenario.next_tx(ADMIN);

    world.scenario.take_shared<MemezFun<Auction, Meme>>()
}

fun assert_eq_reduce_precision(value: u64, expected: u64, decimals_precision: u8) {
    let x = value / 10u64.pow(decimals_precision);
    let y = expected / 10u64.pow(decimals_precision);

    assert_eq(x, y);
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

    memez_auction_config::initialize(&mut config);

    let clock = clock::create_for_testing(scenario.ctx());

    World { config, migrator_list, clock, scenario }
}

fun end(world: World) {
    destroy(world);
}
