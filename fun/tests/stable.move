#[test_only]
module memez_fun::memez_stable_tests;

use memez_acl::acl;
use memez_fun::{
    memez_config::{Self, MemezConfig},
    memez_errors,
    memez_fun::{Self, MemezFun},
    memez_migrator_list::{Self, MemezMigratorList},
    memez_stable::{Self, Stable},
    memez_stable_config,
    memez_version
};
use sui::{
    coin::{Self, mint_for_testing, create_treasury_cap_for_testing, Coin},
    sui::SUI,
    test_scenario::{Self as ts, Scenario},
    test_utils::{assert_eq, destroy},
    token
};

const ADMIN: address = @0x1;

const DEAD_ADDRESS: address = @0x0;

const POW_9: u64 = 1__000_000_000;

public struct World {
    config: MemezConfig,
    migrator_list: MemezMigratorList,
    scenario: Scenario,
}

public struct Meme has drop ()

public struct MigrationWitness has drop ()

fun set_up_pool(
    world: &mut World,
    is_token: bool,
    dev_payload: vector<u64>,
    total_supply: u64,
): MemezFun<Stable, Meme> {
    let ctx = world.scenario.ctx();

    let metadata_cap = memez_stable::new<Meme, MigrationWitness>(
        &world.config,
        &world.migrator_list,
        create_treasury_cap_for_testing(ctx),
        mint_for_testing(2_000_000_000, ctx),
        total_supply,
        is_token,
        vector[],
        vector[],
        dev_payload,
        memez_version::get_version_for_testing(1),
        ctx,
    );

    metadata_cap.destroy();

    world.scenario.next_tx(ADMIN);

    world.scenario.take_shared<MemezFun<Stable, Meme>>()
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

    World { config, migrator_list, scenario }
}

fun end(world: World) {
    destroy(world);
}
