#[test_only]
module memez_fun::memez_auction_tests;

use constant_product::constant_product::get_amount_out;
use ipx_coin_standard::ipx_coin_standard::IPXTreasuryStandard;
use memez_acl::acl;
use memez_fun::{
    memez_auction::{Self, Auction},
    memez_config::{Self, MemezConfig},
    memez_errors,
    memez_fun::{Self, MemezFun},
    memez_migrator_list::{Self, MemezMigratorList},
    memez_stable_config,
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

    memez_stable_config::initialize(&mut config);

    let clock = clock::create_for_testing(scenario.ctx());

    World { config, migrator_list, clock, scenario }
}

fun end(world: World) {
    destroy(world);
}
