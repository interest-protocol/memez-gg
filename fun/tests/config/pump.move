#[test_only]
module memez_fun::memez_pump_config_tests;

use memez_acl::acl;
use memez_fun::{memez_config::{Self, MemezConfig}, memez_errors, memez_pump_config};
use sui::{test_scenario::{Self as ts, Scenario}, test_utils::{assert_eq, destroy}};

const BURN_TAX: u64 = 200_000_000;

const MAX_BURN_TAX: u64 = 500_000_000;

const LIQUIDITY_PROVISION: u64 = 50_000_000__000_000_000;

const VIRTUAL_LIQUIDITY: u64 = 1_000__000_000_000;

const TARGET_SUI_LIQUIDITY: u64 = 10_000__000_000_000;

const TOTAL_SUPPLY: u64 = 1_000_000_000__000_000_000;

const ADMIN: address = @0x1;

public struct World {
    scenario: Scenario,
    config: MemezConfig,
}

#[test]
fun test_initialize() {
    let mut world = start();

    assert_eq(memez_pump_config::is_initialized(&world.config), false);

    memez_pump_config::initialize(&mut world.config);

    assert_eq(memez_pump_config::is_initialized(&world.config), true);

    let config = memez_pump_config::get(&world.config, TOTAL_SUPPLY);

    assert_eq(config[0], BURN_TAX);
    assert_eq(config[1], VIRTUAL_LIQUIDITY);
    assert_eq(config[2], TARGET_SUI_LIQUIDITY);
    assert_eq(config[3], LIQUIDITY_PROVISION);

    world.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EAlreadyInitialized,
        location = memez_pump_config,
    ),
]
fun test_initialize_twice() {
    let mut world = start();

    memez_pump_config::initialize(&mut world.config);

    memez_pump_config::initialize(&mut world.config);

    world.end();
}

#[test]
fun test_setters() {
    let mut world = start();

    memez_pump_config::initialize(&mut world.config);

    let witness = acl::sign_in_for_testing();

    let config = memez_pump_config::get(&world.config, TOTAL_SUPPLY);

    assert_eq(config[0], BURN_TAX);
    assert_eq(config[1], VIRTUAL_LIQUIDITY);
    assert_eq(config[2], TARGET_SUI_LIQUIDITY);
    assert_eq(config[3], LIQUIDITY_PROVISION);

    memez_pump_config::set_burn_tax(&mut world.config, &witness, BURN_TAX + 3);
    memez_pump_config::set_virtual_liquidity(&mut world.config, &witness, VIRTUAL_LIQUIDITY + 4);
    memez_pump_config::set_target_sui_liquidity(
        &mut world.config,
        &witness,
        TARGET_SUI_LIQUIDITY + 5,
    );
    memez_pump_config::set_liquidity_provision(
        &mut world.config,
        &witness,
        LIQUIDITY_PROVISION + 6,
    );

    let config = memez_pump_config::get(&world.config, TOTAL_SUPPLY);

    assert_eq(config[0], BURN_TAX + 3);
    assert_eq(config[1], VIRTUAL_LIQUIDITY + 4);
    assert_eq(config[2], TARGET_SUI_LIQUIDITY + 5);
    assert_eq(config[3], LIQUIDITY_PROVISION + 6);

    world.end();
}

#[test]
fun test_get_liquidity_provision() {
    let mut world = start();

    memez_pump_config::initialize(&mut world.config);

    let config = memez_pump_config::get(&world.config, 100);

    assert_eq(config[3], 5);

    world.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EBurnTaxExceedsMax,
        location = memez_pump_config,
    ),
]
fun test_set_burn_tax_exceeds_max() {
    let mut world = start();

    memez_pump_config::initialize(&mut world.config);

    let witness = acl::sign_in_for_testing();

    memez_pump_config::set_burn_tax(&mut world.config, &witness, MAX_BURN_TAX + 1);

    world.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EInvalidTargetSuiLiquidity,
        location = memez_pump_config,
    ),
]
fun test_set_target_sui_liquidity_invalid() {
    let mut world = start();

    memez_pump_config::initialize(&mut world.config);

    let witness = acl::sign_in_for_testing();

    memez_pump_config::set_target_sui_liquidity(&mut world.config, &witness, VIRTUAL_LIQUIDITY);

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
