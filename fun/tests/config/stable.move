#[test_only]
module memez_fun::memez_stable_config_tests;

use memez_acl::acl;
use memez_fun::{memez_config::{Self, MemezConfig}, memez_stable_config};
use sui::{test_scenario::{Self as ts, Scenario}, test_utils::{assert_eq, destroy}};

const LIQUIDITY_PROVISION: u64 = 50_000_000__000_000_000;

const TARGET_SUI_LIQUIDITY: u64 = 10_000__000_000_000;

const MEME_SALE_AMOUNT: u64 = 400_000_000_000;

const ADMIN: address = @0x1;

public struct World {
    scenario: Scenario,
    config: MemezConfig,
}

#[test]
fun test_initialize() {
    let mut world = start();

    assert_eq(memez_stable_config::is_initialized(&world.config), false);

    memez_stable_config::initialize(&mut world.config);

    assert_eq(memez_stable_config::is_initialized(&world.config), true);

    let config = memez_stable_config::get(&world.config);

    assert_eq(config[0], TARGET_SUI_LIQUIDITY);
    assert_eq(config[1], LIQUIDITY_PROVISION);
    assert_eq(config[2], MEME_SALE_AMOUNT);

    world.end();
}

#[test]
fun test_setters() {
    let mut world = start();

    memez_stable_config::initialize(&mut world.config);

    let witness = acl::sign_in_for_testing();

    let config = memez_stable_config::get(&world.config);

    assert_eq(config[0], TARGET_SUI_LIQUIDITY);
    assert_eq(config[1], LIQUIDITY_PROVISION);
    assert_eq(config[2], MEME_SALE_AMOUNT);

    memez_stable_config::set_target_sui_liquidity(
        &mut world.config,
        &witness,
        TARGET_SUI_LIQUIDITY + 1,
    );

    memez_stable_config::set_liquidity_provision(
        &mut world.config,
        &witness,
        LIQUIDITY_PROVISION + 2,
    );

    memez_stable_config::set_meme_sale_amount(
        &mut world.config,
        &witness,
        MEME_SALE_AMOUNT + 3,
    );

    let config = memez_stable_config::get(&world.config);

    assert_eq(config[0], TARGET_SUI_LIQUIDITY + 1);
    assert_eq(config[1], LIQUIDITY_PROVISION + 2);
    assert_eq(config[2], MEME_SALE_AMOUNT + 3);

    world.end();
}

#[test]
#[expected_failure(abort_code = memez_stable_config::EAlreadyInitialized)]
fun test_initialize_twice() {
    let mut world = start();

    memez_stable_config::initialize(&mut world.config);

    memez_stable_config::initialize(&mut world.config);

    world.end();
}

fun start(): World {
    let mut scenario = ts::begin(ADMIN);

    memez_config::init_for_testing(scenario.ctx());

    scenario.next_epoch(ADMIN);

    let config = scenario.take_shared<MemezConfig>();

    World {
        scenario,
        config,
    }
}

fun end(world: World) {
    destroy(world);
}
