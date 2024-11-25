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
    memez_version,
    memez_fixed_rate
};
use sui::{
    clock,
    balance,
    coin::{Self, mint_for_testing, create_treasury_cap_for_testing, Coin},
    sui::SUI,
    test_scenario::{Self as ts, Scenario},
    test_utils::{assert_eq, destroy},
    token
};

const ADMIN: address = @0x1;

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
fun test_new_token() {
    let mut world = start();

    let total_supply = POW_9 * POW_9;

    let dev_allocation = POW_9 / 10;

    let target_sui_liquidity = 10_000 * POW_9;

    let mut memez_fun = set_up_pool(&mut world, true, target_sui_liquidity, vector[dev_allocation, DAY], total_supply);

    memez_fun.assert_uses_token(); 

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

#[test]
fun test_coin_end_to_end() {
    let mut world = start();

    let total_supply = POW_9 * POW_9;

    let dev_allocation = POW_9 / 10;

    let target_sui_liquidity = 10_000 * POW_9;

    let stable_config = memez_stable_config::get(&world.config, total_supply);

    let mut memez_fun = set_up_pool(&mut world, false, target_sui_liquidity, vector[dev_allocation, DAY], total_supply);

    world.scenario.next_tx(ADMIN);

    let creation_fee = world.scenario.take_from_address<Coin<SUI>>(@treasury);

    assert_eq(creation_fee.burn_for_testing(), world.config.creation_fee());

    let mut fr = memez_fixed_rate::new<Meme>(
        target_sui_liquidity,
        balance::create_for_testing(stable_config[2]),
    );

    let (expected_excess_sui_coin, expected_meme_coin) = fr.pump_amount(1000 * POW_9);

    let (excess_sui_coin, meme_coin) = memez_stable::pump(
        &mut memez_fun,
        coin::mint_for_testing(1000 * POW_9, world.scenario.ctx()),
        expected_excess_sui_coin,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    assert_eq(excess_sui_coin.burn_for_testing(), expected_excess_sui_coin);
    assert_eq(0, expected_excess_sui_coin);
    assert_eq(meme_coin.burn_for_testing(), expected_meme_coin);

    memez_fun.assert_is_bonding();

    let (_, x, y) = fr.pump(
        coin::mint_for_testing(1000 * POW_9, world.scenario.ctx()),
        0,
        world.scenario.ctx(),
    );

    x.burn_for_testing();
    y.burn_for_testing();

    let expected_sui_value = fr.dump_amount(expected_meme_coin);

    let sui_coin = memez_stable::dump(
        &mut memez_fun,
        coin::mint_for_testing(expected_meme_coin, world.scenario.ctx()),
        expected_sui_value,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    assert_eq(sui_coin.burn_for_testing(), expected_sui_value);
    assert_eq(1000 * POW_9, expected_sui_value);

    let (excess_sui_coin, meme_coin) = memez_stable::pump(
        &mut memez_fun,
        coin::mint_for_testing(1000 * POW_9 + target_sui_liquidity, world.scenario.ctx()),
        expected_excess_sui_coin,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    assert_eq(excess_sui_coin.burn_for_testing(), 1000 * POW_9);
    assert_eq(meme_coin.burn_for_testing(), stable_config[2]);

    memez_fun.assert_is_migrating();

    let migrator = memez_stable::migrate(
        &mut memez_fun,
        &world.config,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    let (sui_balance_after, meme_balance_after) = migrator.destroy(MigrationWitness());

    assert_eq(sui_balance_after.destroy_for_testing(), target_sui_liquidity - world.config.migration_fee());
    assert_eq(meme_balance_after.destroy_for_testing(), stable_config[1]);

    memez_fun.assert_migrated();

    world.scenario.next_tx(ADMIN);

    let migration_fee = world.scenario.take_from_address<Coin<SUI>>(@treasury);

    assert_eq(migration_fee.burn_for_testing(), world.config.migration_fee());

    destroy(fr);
    destroy(memez_fun);
    world.end();
}

#[test]
fun test_token_end_to_end() {
    let mut world = start();

    let total_supply = POW_9 * POW_9;

    let dev_allocation = POW_9 / 10;

    let target_sui_liquidity = 10_000 * POW_9;

    let stable_config = memez_stable_config::get(&world.config, total_supply);

    let mut memez_fun = set_up_pool(&mut world, true, target_sui_liquidity, vector[dev_allocation, DAY], total_supply);

    world.scenario.next_tx(ADMIN);

    let creation_fee = world.scenario.take_from_address<Coin<SUI>>(@treasury);

    assert_eq(creation_fee.burn_for_testing(), world.config.creation_fee());

    let mut fr = memez_fixed_rate::new<Meme>(
        target_sui_liquidity,
        balance::create_for_testing(stable_config[2]),
    );

    let (expected_excess_sui_coin, expected_meme_coin) = fr.pump_amount(1000 * POW_9);

    let (excess_sui_coin, meme_token) = memez_stable::pump_token(
        &mut memez_fun,
        coin::mint_for_testing(1000 * POW_9, world.scenario.ctx()),
        expected_excess_sui_coin,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    assert_eq(excess_sui_coin.burn_for_testing(), expected_excess_sui_coin);
    assert_eq(0, expected_excess_sui_coin);
    assert_eq(meme_token.value(), expected_meme_coin);

    meme_token.burn_for_testing();

    memez_fun.assert_is_bonding();

    let (_, x, y) = fr.pump(
        coin::mint_for_testing(1000 * POW_9, world.scenario.ctx()),
        0,
        world.scenario.ctx(),
    );

    x.burn_for_testing();
    y.burn_for_testing();

    let expected_sui_value = fr.dump_amount(expected_meme_coin);

    let sui_coin = memez_stable::dump_token(
        &mut memez_fun,
        token::mint_for_testing(expected_meme_coin, world.scenario.ctx()),
        expected_sui_value,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    assert_eq(sui_coin.burn_for_testing(), expected_sui_value);
    assert_eq(1000 * POW_9, expected_sui_value);

    let (excess_sui_coin, meme_token) = memez_stable::pump_token(
        &mut memez_fun,
        coin::mint_for_testing(1000 * POW_9 + target_sui_liquidity, world.scenario.ctx()),
        expected_excess_sui_coin,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    assert_eq(excess_sui_coin.burn_for_testing(), 1000 * POW_9);
    assert_eq(meme_token.value(), stable_config[2]);

    memez_fun.assert_is_migrating();

    let migrator = memez_stable::migrate(
        &mut memez_fun,
        &world.config,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    let (sui_balance_after, meme_balance_after) = migrator.destroy(MigrationWitness());

    assert_eq(sui_balance_after.destroy_for_testing(), target_sui_liquidity - world.config.migration_fee());
    assert_eq(meme_balance_after.destroy_for_testing(), stable_config[1]);

    memez_fun.assert_migrated();

    let meme_coin = memez_stable::to_coin(&mut memez_fun, meme_token, world.scenario.ctx());

    assert_eq(meme_coin.burn_for_testing(), stable_config[2]);

    let mut clock = clock::create_for_testing(world.scenario.ctx());

    let mut memez_vesting = memez_stable::dev_claim(
        &mut memez_fun,
        &clock,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    assert_eq(memez_vesting.balance(), dev_allocation);
    assert_eq(memez_vesting.duration(), DAY);
    assert_eq(memez_vesting.start(), 0);

    world.scenario.next_tx(ADMIN);

    let migration_fee = world.scenario.take_from_address<Coin<SUI>>(@treasury);

    assert_eq(migration_fee.burn_for_testing(), world.config.migration_fee());

    clock.increment_for_testing(DAY + 1);

    let dev_meme_coin = memez_vesting.claim(&clock, world.scenario.ctx());

    memez_vesting.destroy_zero();

    assert_eq(dev_meme_coin.burn_for_testing(), dev_allocation);

    destroy(clock);
    destroy(fr);
    destroy(memez_fun);
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

#[
    test,
    expected_failure(
        abort_code = memez_errors::EOutdatedPackageVersion,
        location = memez_version,
    ),
]
fun pump_invalid_version() {
    let mut world = start();

    let total_supply = POW_9 * POW_9;

    let dev_allocation = POW_9 / 10;

    let mut memez_fun = set_up_pool(&mut world, false, POW_9 * POW_9, vector[dev_allocation, DAY], total_supply);

    let (x, y) = memez_stable::pump(
        &mut memez_fun,
        coin::mint_for_testing(1000 * POW_9, world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(2),
        world.scenario.ctx(),
    );

    x.burn_for_testing();
    y.burn_for_testing();

    destroy(memez_fun);
    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ETokenSupported, location = memez_fun)]
fun pump_use_token_instead() {
    let mut world = start();

    let total_supply = POW_9 * POW_9;

    let dev_allocation = POW_9 / 10;

    let mut memez_fun = set_up_pool(&mut world, true, POW_9 * POW_9, vector[dev_allocation, DAY], total_supply);

    let (x, y) = memez_stable::pump(
        &mut memez_fun,
        coin::mint_for_testing(1000 * POW_9, world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    x.burn_for_testing();
    y.burn_for_testing();

    destroy(memez_fun);
    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ENotBonding, location = memez_fun)]
fun pump_is_not_bonding() {
    let mut world = start();

    let total_supply = POW_9 * POW_9;

    let dev_allocation = POW_9 / 10;

    let mut memez_fun = set_up_pool(&mut world, false, 10_000 * POW_9, vector[dev_allocation, DAY], total_supply);

    let (x, y) = memez_stable::pump(
        &mut memez_fun,
        coin::mint_for_testing(10_000 * POW_9, world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    x.burn_for_testing();
    y.burn_for_testing();

    let (x, y) = memez_stable::pump(
        &mut memez_fun,
        coin::mint_for_testing(POW_9, world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    x.burn_for_testing();
    y.burn_for_testing();

    destroy(memez_fun);
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
