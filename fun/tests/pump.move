#[test_only]
module memez_fun::memez_pump_tests;

use constant_product::constant_product::get_amount_out;
use ipx_coin_standard::ipx_coin_standard::IPXTreasuryStandard;
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

const DEAD_ADDRESS: address = @0x0;

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

    let sui_dev_value = memez_pump::dev_purchase(&mut memez_fun);

    let cp = memez_pump::constant_product_mut(&mut memez_fun);

    let expected_sui_dev_value = get_amount_out(
        first_purchase_value,
        cp.virtual_liquidity(),
        cp.meme_balance().value() + sui_dev_value,
    );

    world.scenario.next_tx(DEAD_ADDRESS);

    let sui_fee_coin = world.scenario.take_from_address<Coin<SUI>>(@treasury);

    assert_eq(sui_fee_coin.burn_for_testing(), 2 * POW_9);

    let purchase_sui_value = 2_000 * POW_9;

    let ctx = world.scenario.ctx();

    let cp = memez_pump::constant_product_mut(&mut memez_fun);

    let expected_meme_value = get_amount_out(
        purchase_sui_value,
        cp.virtual_liquidity() + cp.sui_balance().value(),
        cp.meme_balance().value(),
    );

    let meme_coin = memez_pump::pump(
        &mut memez_fun,
        mint_for_testing(purchase_sui_value, ctx),
        expected_meme_value,
        memez_version::get_version_for_testing(1),
        ctx,
    );

    assert_eq(meme_coin.burn_for_testing(), expected_meme_value);

    let mut treasury = world.scenario.take_shared<IPXTreasuryStandard>();

    let ctx = world.scenario.ctx();

    let sell_meme_value = expected_meme_value / 3;

    let cp = memez_pump::constant_product_mut(&mut memez_fun);

    let (expected_sui_value, _) = cp.dump_amount(sell_meme_value, 0);

    let sui_coin = memez_pump::dump(
        &mut memez_fun,
        &mut treasury,
        mint_for_testing(sell_meme_value, ctx),
        expected_sui_value,
        memez_version::get_version_for_testing(1),
        ctx,
    );

    assert_eq(sui_coin.burn_for_testing(), expected_sui_value);

    let purchase_sui_value = 8_000 * POW_9 + expected_sui_value;

    let ctx = world.scenario.ctx();

    let cp = memez_pump::constant_product_mut(&mut memez_fun);

    let expected_meme_value = get_amount_out(
        purchase_sui_value,
        cp.virtual_liquidity() + cp.sui_balance().value(),
        cp.meme_balance().value(),
    );

    memez_fun.assert_is_bonding();

    let meme_coin = memez_pump::pump(
        &mut memez_fun,
        mint_for_testing(purchase_sui_value, ctx),
        expected_meme_value,
        memez_version::get_version_for_testing(1),
        ctx,
    );

    assert_eq(meme_coin.burn_for_testing(), expected_meme_value);

    memez_fun.assert_is_migrating();

    let config = &world.config;

    let ctx = world.scenario.ctx();

    let sui_balance_value = memez_pump::constant_product_mut(&mut memez_fun).sui_balance().value();

    let migrator = memez_pump::migrate(
        &mut memez_fun,
        config,
        memez_version::get_version_for_testing(1),
        ctx,
    );

    memez_fun.assert_migrated();

    let (sui_balance, meme_balance) = migrator.destroy(MigrationWitness());

    world.scenario.next_tx(DEAD_ADDRESS);

    let sui_fee_coin = world.scenario.take_from_address<Coin<SUI>>(@treasury);

    assert_eq(sui_fee_coin.burn_for_testing(), 200 * POW_9);

    let config = memez_pump_config::get(&world.config, total_supply);

    assert_eq(sui_balance.destroy_for_testing(), sui_balance_value - 200 * POW_9);
    assert_eq(sui_balance_value >= config[2], true);
    assert_eq(meme_balance.destroy_for_testing(), config[3]);

    world.scenario.next_tx(ADMIN);

    let ctx = world.scenario.ctx();

    let sui_dev_coin = memez_pump::dev_claim(
        &mut memez_fun,
        memez_version::get_version_for_testing(1),
        ctx,
    );

    assert_eq(sui_dev_coin.burn_for_testing(), expected_sui_dev_value);

    destroy(memez_fun);
    destroy(treasury);

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
