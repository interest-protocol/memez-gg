#[test_only]
module memez_fun::memez_pump_tests;

use constant_product::constant_product::get_amount_out;
use memez_acl::acl;
use memez_fun::{
    memez_config::{Self, MemezConfig},
    memez_fun::MemezFun,
    memez_migrator_list::{Self, MemezMigratorList},
    memez_pump::{Self, Pump},
    memez_pump_config,
    memez_version
};
use sui::{
    coin::{mint_for_testing, create_treasury_cap_for_testing, Coin},
    sui::SUI,
    test_scenario::{Self as ts, Scenario},
    test_utils::{assert_eq, destroy}
};

const ADMIN: address = @0x1;

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

    let first_purchase_value = 50_000_000_000;

    let total_supply = 1_000_000_000_000_000_000;

    let first_purchase = mint_for_testing(first_purchase_value, world.scenario.ctx());

    let mut memez_fun = set_up_pool(
        &mut world,
        first_purchase,
        false,
        total_supply,
    );

    memez_fun.assert_uses_coin();

    let config = memez_pump_config::get(&world.config, total_supply);

    assert_eq(memez_pump::liquidity_provision(&mut memez_fun), config[3]);

    let dev_purchase = memez_pump::dev_purchase(&mut memez_fun);

    let expected_dev_purchase = get_amount_out(
        first_purchase_value,
        config[1],
        total_supply - config[3],
    );

    let cp = memez_pump::constant_product_mut(&mut memez_fun);

    assert_eq(cp.virtual_liquidity(), config[1]);
    assert_eq(cp.target_sui_liquidity(), config[2]);
    assert_eq(cp.sui_balance().value(), first_purchase_value);
    assert_eq(cp.meme_balance().value(), total_supply - config[3] - dev_purchase);
    assert_eq(dev_purchase, expected_dev_purchase);

    destroy(memez_fun);
    end(world);
}

#[test]
fun test_new_token() {
    let mut world = start();

    let first_purchase_value = 0;

    let total_supply = 2_000_000_000_000_000_000;

    let first_purchase = mint_for_testing(first_purchase_value, world.scenario.ctx());

    let mut memez_fun = set_up_pool(
        &mut world,
        first_purchase,
        true,
        total_supply,
    );

    memez_fun.assert_uses_token();

    let config = memez_pump_config::get(&world.config, total_supply);

    assert_eq(memez_pump::liquidity_provision(&mut memez_fun), config[3]);

    let dev_purchase = memez_pump::dev_purchase(&mut memez_fun);

    let expected_dev_purchase = 0;

    let cp = memez_pump::constant_product_mut(&mut memez_fun);

    assert_eq(cp.virtual_liquidity(), config[1]);
    assert_eq(cp.target_sui_liquidity(), config[2]);
    assert_eq(cp.sui_balance().value(), first_purchase_value);
    assert_eq(cp.meme_balance().value(), total_supply - config[3] - dev_purchase);
    assert_eq(dev_purchase, expected_dev_purchase);

    destroy(memez_fun);
    end(world);
}

#[test]
fun test_coin_end_to_end() {
    let mut world = start();

    let first_purchase_value = 50_000_000_000;

    let total_supply = 1_000_000_000_000_000_000;

    let first_purchase = mint_for_testing(first_purchase_value, world.scenario.ctx());

    let mut memez_fun = set_up_pool(
        &mut world,
        first_purchase,
        false,
        total_supply,
    );

    destroy(memez_fun);

    world.end();
}

fun set_up_pool(
    world: &mut World,
    first_purchase: Coin<SUI>,
    is_token: bool,
    total_supply: u64,
): MemezFun<Pump, Meme> {
    let ctx = world.scenario.ctx();

    let version = memez_version::get_version_for_testing(1);

    let metadata_cap = memez_pump::new<Meme, MigrationWitness>(
        &world.config,
        &world.migrator_list,
        create_treasury_cap_for_testing(ctx),
        mint_for_testing(2_000_000_000, ctx),
        total_supply,
        is_token,
        first_purchase,
        vector[],
        vector[],
        version,
        ctx,
    );

    metadata_cap.destroy();

    world.scenario.next_tx(ADMIN);

    world.scenario.take_shared<MemezFun<Pump, Meme>>()
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

    memez_pump_config::initialize(&mut config);

    World { config, migrator_list, scenario }
}

fun end(world: World) {
    destroy(world);
}
