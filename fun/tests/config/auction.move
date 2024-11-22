#[test_only]
module memez_fun::memez_auction_config_tests;

use memez_acl::acl;
use memez_fun::{memez_auction_config, memez_config::{Self, MemezConfig}};
use sui::{test_scenario::{Self as ts, Scenario}, test_utils::{assert_eq, destroy}};

const ADMIN: address = @0x1;

const BURN_TAX: u64 = 200_000_000;

const MAX_BURN_TAX: u64 = 500_000_000;

const POW_18: u64 = 1__000_000_000_000_000_000;

const TOTAL_SUPPLY: u64 = 1_000_000_000__000_000_000;

// @dev 10,000,000 = 1%
const DEV_ALLOCATION: u64 = { POW_18 / 100 };

// @dev 50,000,000 = 5%
const LIQUIDITY_PROVISION: u64 = { POW_18 / 20 };

const THIRTY_MINUTES_MS: u64 = 30 * 60 * 1_000;

const VIRTUAL_LIQUIDITY: u64 = 1_000__000_000_000;

const TARGET_SUI_LIQUIDITY: u64 = 10_000__000_000_000;

const SEED_LIQUIDITY: u64 = { POW_18 / 10_000 };

public struct World {
    scenario: Scenario,
    config: MemezConfig,
}

#[test]
fun test_initialize() {
    let mut world = start();

    assert_eq(memez_auction_config::is_initialized(&world.config), false);

    memez_auction_config::initialize(&mut world.config);

    assert_eq(memez_auction_config::is_initialized(&world.config), true);

    let config = memez_auction_config::get(&world.config, TOTAL_SUPPLY);

    assert_eq(config[0], THIRTY_MINUTES_MS);
    assert_eq(config[1], DEV_ALLOCATION);
    assert_eq(config[2], BURN_TAX);
    assert_eq(config[3], VIRTUAL_LIQUIDITY);
    assert_eq(config[4], TARGET_SUI_LIQUIDITY);
    assert_eq(config[5], LIQUIDITY_PROVISION);
    assert_eq(config[6], 100000000000000);

    world.end();
}

#[test, expected_failure(abort_code = memez_auction_config::EAlreadyInitialized)]
fun test_initialize_twice() {
    let mut world = start();

    memez_auction_config::initialize(&mut world.config);

    memez_auction_config::initialize(&mut world.config);

    world.end();
}

#[test]
fun test_setters() {
    let mut world = start();

    memez_auction_config::initialize(&mut world.config);

    let config = memez_auction_config::get(&world.config, TOTAL_SUPPLY);

    assert_eq(config[0], THIRTY_MINUTES_MS);
    assert_eq(config[1], DEV_ALLOCATION);
    assert_eq(config[2], BURN_TAX);
    assert_eq(config[3], VIRTUAL_LIQUIDITY);
    assert_eq(config[4], TARGET_SUI_LIQUIDITY);
    assert_eq(config[5], LIQUIDITY_PROVISION);
    assert_eq(config[6], SEED_LIQUIDITY);

    let witness = acl::sign_in_for_testing();

    memez_auction_config::set_burn_tax(&mut world.config, &witness, 100);
    memez_auction_config::set_virtual_liquidity(&mut world.config, &witness, 1111);
    memez_auction_config::set_target_sui_liquidity(&mut world.config, &witness, 2222);
    memez_auction_config::set_liquidity_provision(&mut world.config, &witness, 3333);
    memez_auction_config::set_seed_liquidity(&mut world.config, &witness, 4444);
    memez_auction_config::set_auction_duration(&mut world.config, &witness, 5555);
    memez_auction_config::set_dev_allocation(&mut world.config, &witness, 6666);

    let config = memez_auction_config::get(&world.config, TOTAL_SUPPLY);

    assert_eq(config[0], 5555);
    assert_eq(config[1], 6666);
    assert_eq(config[2], 100);
    assert_eq(config[3], 1111);
    assert_eq(config[4], 2222);
    assert_eq(config[5], 3333);
    assert_eq(config[6], 4444);

    world.end();
}

#[test]
public fun test_percentage_calculation() {
    let mut world = start();

    memez_auction_config::initialize(&mut world.config);

    let config = memez_auction_config::get(&world.config, 333);

    assert_eq(config[1], 3);
    assert_eq(config[5], 16);
    assert_eq(config[6], 100);

    let config = memez_auction_config::get(&world.config, 5_000_000);

    assert_eq(config[1], 50_000);
    assert_eq(config[5], 250_000);
    assert_eq(config[6], 500);

    world.end();
}

#[test, expected_failure(abort_code = memez_auction_config::EBurnTaxExceedsMax)]
fun test_set_burn_tax_too_high() {
    let mut world = start();

    memez_auction_config::initialize(&mut world.config);

    let witness = acl::sign_in_for_testing();

    memez_auction_config::set_burn_tax(&mut world.config, &witness, MAX_BURN_TAX + 1);

    world.end();
}

#[test, expected_failure(abort_code = memez_auction_config::EInvalidTargetSuiLiquidity)]
fun test_set_burn_tax_negative() {
    let mut world = start();

    memez_auction_config::initialize(&mut world.config);

    let witness = acl::sign_in_for_testing();

    memez_auction_config::set_target_sui_liquidity(&mut world.config, &witness, VIRTUAL_LIQUIDITY);

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
