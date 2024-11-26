#[test_only]
module memez_fun::memez_auction_tests;

use constant_product::constant_product::get_amount_out;
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

const POW_18: u64 = 1__000_000_000_000_000_000;

const BURN_TAX: u64 = { POW_9 / 5 };

const MAX_BURN_TAX: u64 = { POW_9 / 2 };

// @dev 10,000,000 = 1%
const DEV_ALLOCATION: u64 = { POW_18 / 100 };

// @dev 50,000,000 = 5%
const LIQUIDITY_PROVISION: u64 = { POW_18 / 20 };

const THIRTY_MINUTES_MS: u64 = 30 * 60 * 1_000;

const VIRTUAL_LIQUIDITY: u64 = { 1_000 * POW_9 };

const TARGET_SUI_LIQUIDITY: u64 = { 10_000 * POW_9 };

const SEED_LIQUIDITY: u64 = { POW_18 / 10_000 };

const MIN_SEED_LIQUIDITY: u64 = 100;

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
