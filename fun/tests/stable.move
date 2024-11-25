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

const DAY: u64 = 86_400_000;

const POW_9: u64 = 1__000_000_000;

public struct World {
    config: MemezConfig,
    migrator_list: MemezMigratorList,
    scenario: Scenario,
}

public struct Meme has drop ()

public struct MigrationWitness has drop ()

#[test]
fun test_new_coin() {
    let mut world = start();

    let total_supply = POW_9 * POW_9;

    let dev_allocation = POW_9 / 10;

    let target_sui_liquidity = 10_000 * POW_9;

    let mut memez_fun = set_up_pool(&mut world, false, target_sui_liquidity, vector[dev_allocation, DAY], total_supply);

    memez_fun.assert_uses_coin(); 

    let stable_config = memez_stable_config::get(&world.config, total_supply);

    assert_eq(memez_stable::dev_allocation(&mut memez_fun), dev_allocation);
    assert_eq(memez_stable::liquidity_provision(&mut memez_fun), stable_config[1]);
    assert_eq(memez_stable::vesting_period(&mut memez_fun), DAY);

    let fr = memez_stable::fixed_rate(&mut memez_fun);

    assert_eq(fr.memez_fun(), object::id_address(&memez_fun));
    assert_eq(fr.sui_raise_amount(), target_sui_liquidity);
    assert_eq(fr.meme_sale_amount(), stable_config[2]);
    assert_eq(fr.sui_balance().value(), 0);
    assert_eq(fr.meme_balance().value(), stable_config[2]);

    assert_eq(
        memez_stable::meme_reserve(&mut memez_fun).value(),
        total_supply - dev_allocation - stable_config[2] - stable_config[1],
    );

    destroy(memez_fun);
    world.end();
}
#[test]
fun test_new_max_target_sui_liquidity() {
    let mut world = start();

    let total_supply = POW_9 * POW_9;

    let dev_allocation = POW_9 / 10;

    let mut memez_fun = set_up_pool(&mut world, false, POW_9 * POW_9, vector[dev_allocation, DAY], total_supply);

    let stable_config = memez_stable_config::get(&world.config, total_supply);

    let fr = memez_stable::fixed_rate(&mut memez_fun);

    assert_eq(stable_config[0], fr.sui_raise_amount());

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
fun test_new_invalid_version() {
    let mut world = start();

    let total_supply = POW_9 * POW_9;

    let dev_allocation = POW_9 / 10;

    let metadata_cap = memez_stable::new<Meme, MigrationWitness>(
        &world.config,
        &world.migrator_list,
        create_treasury_cap_for_testing(world.scenario.ctx()),
        mint_for_testing(2_000_000_000, world.scenario.ctx()),
        10_000 * POW_9,
        total_supply,
        false,
        vector[],
        vector[],
        vector[dev_allocation, DAY],
        memez_version::get_version_for_testing(2),
        world.scenario.ctx(),
    );

    metadata_cap.destroy();
    world.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::ENotEnoughSuiForCreationFee,
        location = memez_config,
    ),
]
fun test_new_invalid_creation_fee() {
    let mut world = start();

    let total_supply = POW_9 * POW_9;

    let dev_allocation = POW_9 / 10;

    let metadata_cap = memez_stable::new<Meme, MigrationWitness>(
        &world.config,
        &world.migrator_list,
        create_treasury_cap_for_testing(world.scenario.ctx()),
        mint_for_testing(2_000_000_000 - 1, world.scenario.ctx()),
        10_000 * POW_9,
        total_supply,
        false,
        vector[],
        vector[],
        vector[dev_allocation, DAY],
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    metadata_cap.destroy();
    world.end();
}

fun set_up_pool(
    world: &mut World,
    is_token: bool,
    target_sui_liquidity: u64,
    dev_payload: vector<u64>,
    total_supply: u64,
): MemezFun<Stable, Meme> {
    let ctx = world.scenario.ctx();

    let metadata_cap = memez_stable::new<Meme, MigrationWitness>(
        &world.config,
        &world.migrator_list,
        create_treasury_cap_for_testing(ctx),
        mint_for_testing(2_000_000_000, ctx),
        target_sui_liquidity,
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
