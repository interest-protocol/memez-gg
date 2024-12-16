#[test_only]
module memez_fun::memez_pump_tests;

use interest_bps::bps;
use memez_vesting::memez_vesting::MemezVesting;
use constant_product::constant_product::get_amount_out;
use ipx_coin_standard::ipx_coin_standard::IPXTreasuryStandard;
use memez_acl::acl;
use memez_fun::{
    memez_config::{Self, MemezConfig, DefaultKey},
    memez_errors,
    memez_fees,
    memez_fun::{Self, MemezFun},
    memez_migrator_list::{Self, MemezMigratorList},
    memez_pump::{Self, Pump},
    memez_version,
    memez_test_helpers::add_fee
};
use sui::{
    coin::{Self, mint_for_testing, create_treasury_cap_for_testing, Coin},
    sui::SUI,
    clock,
    test_scenario::{Self as ts, Scenario},
    test_utils::{assert_eq, destroy},
    token
};

const ADMIN: address = @0x1;

const DEAD_ADDRESS: address = @0x0;

const POW_9: u64 = 1__000_000_000;

const MAX_BPS: u64 = 10_000;

const BURN_TAX: u64 = 30;

const VIRTUAL_LIQUIDITY: u64 = 200 * POW_9;

const TARGET_LIQUIDITY: u64 = 10_000 * POW_9;

const PROVISION_LIQUIDITY: u64 = 500;

const DEV: address = @0x2;

const STAKE_HOLDER: address = @0x3;

const VESTING_PERIOD: u64 = 100;

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

    let config = world.config.get_pump<DefaultKey>(total_supply);

    assert_eq(memez_pump::liquidity_provision(&mut memez_fun), config[3]);

    let dev_purchase = memez_pump::dev_purchase(&mut memez_fun);

    let cp = memez_pump::constant_product_mut(&mut memez_fun);

    let swap_fee = cp.swap_fee().calculate(first_purchase_value);

    let expected_dev_purchase = get_amount_out(
        first_purchase_value - swap_fee,
        config[1],
        total_supply - config[3],
    );

    let cp = memez_pump::constant_product_mut(&mut memez_fun);

    assert_eq(cp.virtual_liquidity(), config[1]);
    assert_eq(cp.target_sui_liquidity(), config[2]);
    assert_eq(cp.sui_balance().value(), first_purchase_value - swap_fee);
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

    let config = world.config.get_pump<DefaultKey>(total_supply);

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

    world.scenario.next_tx(DEV);

    let first_purchase_value = 50_000_000_000;

    let total_supply = 1_000_000_000_000_000_000;

    let first_purchase = mint_for_testing(first_purchase_value, world.scenario.ctx());

    let mut memez_fun = set_up_pool(
        &mut world,
        first_purchase,
        false,
        total_supply,
    );

    let dev_purchase = memez_pump::dev_purchase(&mut memez_fun);

    let cp = memez_pump::constant_product_mut(&mut memez_fun);

    let swap_fee = cp.swap_fee().calculate(first_purchase_value);

    let expected_sui_dev_value = get_amount_out(
        first_purchase_value - swap_fee,
        cp.virtual_liquidity(),
        cp.meme_balance().value() + dev_purchase,
    );

    world.scenario.next_tx(DEAD_ADDRESS);

    let sui_swap_fee_coin = world.scenario.take_from_address<Coin<SUI>>(ADMIN);

    assert_eq(sui_swap_fee_coin.burn_for_testing(), swap_fee);

    let sui_creation_fee_coin = world.scenario.take_from_address<Coin<SUI>>(ADMIN);

    assert_eq(sui_creation_fee_coin.burn_for_testing(), 2 * POW_9);

    let purchase_sui_value = 2_000 * POW_9;

    let ctx = world.scenario.ctx();

    let cp = memez_pump::constant_product_mut(&mut memez_fun);

    let swap_fee = cp.swap_fee().calculate(purchase_sui_value);

    let expected_meme_value = get_amount_out(
        purchase_sui_value - swap_fee,
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

    let amounts  = cp.dump_amount(sell_meme_value, 0);

    let sui_coin = memez_pump::dump(
        &mut memez_fun,
        &mut treasury,
        mint_for_testing(sell_meme_value, ctx),
        amounts[0],
        memez_version::get_version_for_testing(1),
        ctx,
    );

    assert_eq(sui_coin.burn_for_testing(), amounts[0]);

    let purchase_sui_value = 8_000 * POW_9 + amounts[0];

    let cp = memez_pump::constant_product_mut(&mut memez_fun);

    let swap_fee = cp.swap_fee().calculate(purchase_sui_value);

    let ctx = world.scenario.ctx();

    let cp = memez_pump::constant_product_mut(&mut memez_fun);

    let expected_meme_value = get_amount_out(
        purchase_sui_value - swap_fee,
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

    let ctx = world.scenario.ctx();

    let sui_balance_value = memez_pump::constant_product_mut(&mut memez_fun).sui_balance().value();

    let migrator = memez_pump::migrate(
        &mut memez_fun,
        memez_version::get_version_for_testing(1),
        ctx,
    );

    memez_fun.assert_migrated();

    let (sui_balance, meme_balance) = migrator.destroy(MigrationWitness());

    world.scenario.next_tx(DEAD_ADDRESS);

    let sui_fee_coin = world.scenario.take_from_address<Coin<SUI>>(ADMIN);

    assert_eq(sui_fee_coin.burn_for_testing(), 200 * POW_9);

    let config = world.config.get_pump<DefaultKey>(total_supply);

    assert_eq(sui_balance.destroy_for_testing(), sui_balance_value - 200 * POW_9);
    assert_eq(sui_balance_value >= config[2], true);
    assert_eq(meme_balance.destroy_for_testing(), config[3]);

    world.scenario.next_tx(DEV);

    let ctx = world.scenario.ctx();

    let sui_dev_coin = memez_pump::dev_purchase_claim(
        &mut memez_fun,
        memez_version::get_version_for_testing(1),
        ctx,
    );

    assert_eq(sui_dev_coin.burn_for_testing(), expected_sui_dev_value);

    destroy(memez_fun);
    destroy(treasury);

    world.end();
}

#[test]
fun test_token_end_to_end() {
    let mut world = start();

    let first_purchase_value = 50_000_000_000;

    let total_supply = 1_000_000_000_000_000_000;

    let first_purchase = mint_for_testing(first_purchase_value, world.scenario.ctx());

    let mut memez_fun = set_up_pool(
        &mut world,
        first_purchase,
        true,
        total_supply,
    );

    let sui_dev_value = memez_pump::dev_purchase(&mut memez_fun);

    let cp = memez_pump::constant_product_mut(&mut memez_fun);

    let swap_fee = cp.swap_fee().calculate(first_purchase_value);

    let expected_sui_dev_value = get_amount_out(
        first_purchase_value - swap_fee,
        cp.virtual_liquidity(),
        cp.meme_balance().value() + sui_dev_value,
    );

    world.scenario.next_tx(DEAD_ADDRESS);

    let sui_swap_fee_coin = world.scenario.take_from_address<Coin<SUI>>(ADMIN);

    assert_eq(sui_swap_fee_coin.burn_for_testing(), swap_fee);

    let sui_creation_fee_coin = world.scenario.take_from_address<Coin<SUI>>(ADMIN);

    assert_eq(sui_creation_fee_coin.burn_for_testing(), 2 * POW_9);

    let purchase_sui_value = 2_000 * POW_9;

    let ctx = world.scenario.ctx();

    let cp = memez_pump::constant_product_mut(&mut memez_fun);

    let swap_fee = cp.swap_fee().calculate(purchase_sui_value);

    let expected_meme_value = get_amount_out(
        purchase_sui_value - swap_fee,
        cp.virtual_liquidity() + cp.sui_balance().value(),
        cp.meme_balance().value(),
    );

    let meme_token = memez_pump::pump_token(
        &mut memez_fun,
        mint_for_testing(purchase_sui_value, ctx),
        expected_meme_value,
        memez_version::get_version_for_testing(1),
        ctx,
    );

    assert_eq(meme_token.value(), expected_meme_value);

    meme_token.burn_for_testing();

    let mut treasury = world.scenario.take_shared<IPXTreasuryStandard>();

    let ctx = world.scenario.ctx();

    let sell_meme_value = expected_meme_value / 3;

    let cp = memez_pump::constant_product_mut(&mut memez_fun);

    let amounts = cp.dump_amount(sell_meme_value, 0);

    let sui_coin = memez_pump::dump_token(
        &mut memez_fun,
        &mut treasury,
        token::mint_for_testing(sell_meme_value, ctx),
        amounts[0],
        memez_version::get_version_for_testing(1),
        ctx,
    );

    assert_eq(sui_coin.burn_for_testing(), amounts[0]);

    let purchase_sui_value = 8_000 * POW_9 + amounts[0];

    let ctx = world.scenario.ctx();

    let cp = memez_pump::constant_product_mut(&mut memez_fun);

    let swap_fee = cp.swap_fee().calculate(purchase_sui_value);

    let expected_meme_value = get_amount_out(
        purchase_sui_value - swap_fee,
        cp.virtual_liquidity() + cp.sui_balance().value(),
        cp.meme_balance().value(),
    );

    memez_fun.assert_is_bonding();

    let meme_token = memez_pump::pump_token(
        &mut memez_fun,
        mint_for_testing(purchase_sui_value, ctx),
        expected_meme_value,
        memez_version::get_version_for_testing(1),
        ctx,
    );

    assert_eq(meme_token.value(), expected_meme_value);

    memez_fun.assert_is_migrating();

    let ctx = world.scenario.ctx();

    let sui_balance_value = memez_pump::constant_product_mut(&mut memez_fun).sui_balance().value();

    let migrator = memez_pump::migrate(
        &mut memez_fun,
        memez_version::get_version_for_testing(1),
        ctx,
    );

    memez_fun.assert_migrated();

    let (sui_balance, meme_balance) = migrator.destroy(MigrationWitness());

    world.scenario.next_tx(DEAD_ADDRESS);

    let sui_fee_coin = world.scenario.take_from_address<Coin<SUI>>(ADMIN);

    assert_eq(sui_fee_coin.burn_for_testing(), 200 * POW_9);

    let config = world.config.get_pump<DefaultKey>(total_supply);

    assert_eq(sui_balance.destroy_for_testing(), sui_balance_value - 200 * POW_9);
    assert_eq(sui_balance_value >= config[2], true);
    assert_eq(meme_balance.destroy_for_testing(), config[3]);

    world.scenario.next_tx(DEV);

    let ctx = world.scenario.ctx();

    let sui_dev_coin = memez_pump::dev_purchase_claim(
        &mut memez_fun,
        memez_version::get_version_for_testing(1),
        ctx,
    );

    assert_eq(sui_dev_coin.burn_for_testing(), expected_sui_dev_value);

    let meme_coin = memez_pump::to_coin(&mut memez_fun, meme_token, ctx);

    assert_eq(meme_coin.burn_for_testing(), expected_meme_value);

    destroy(memez_fun);
    destroy(treasury);

    world.end();
}


#[
    test,
    expected_failure(
        abort_code = memez_errors::EOutdatedPackageVersion,
        location = memez_version,
    ),
]
fun new_invalid_version() {
    let mut world = start();

    let metadata_cap = memez_pump::new<Meme, DefaultKey, MigrationWitness>(
        &world.config,
        &world.migrator_list,
        create_treasury_cap_for_testing(world.scenario.ctx()),
        mint_for_testing(2_000_000_000, world.scenario.ctx()),
        1_000_000_000_000_000_000,
        false,
        coin::zero(world.scenario.ctx()),
        vector[],
        vector[],
        vector[DEV],
        DEV,
        memez_version::get_version_for_testing(2),
        world.scenario.ctx(),
    );

    destroy(metadata_cap);

    world.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EInsufficientValue,
        location = memez_fees,
    ),
]
fun new_low_creation_fee() {
    let mut world = start();

    let metadata_cap = memez_pump::new<Meme, DefaultKey, MigrationWitness>(
        &world.config,
        &world.migrator_list,
        create_treasury_cap_for_testing(world.scenario.ctx()),
        mint_for_testing(2_000_000_000 - 1, world.scenario.ctx()),
        1_000_000_000_000_000_000,
        false,
        coin::zero(world.scenario.ctx()),
        vector[],
        vector[],
        vector[DEV],
        DEV,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    destroy(metadata_cap);

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

    let first_purchase_value = 50_000_000_000;

    let total_supply = 1_000_000_000_000_000_000;

    let first_purchase = mint_for_testing(first_purchase_value, world.scenario.ctx());

    let mut memez_fun = set_up_pool(
        &mut world,
        first_purchase,
        false,
        total_supply,
    );

    memez_pump::pump(
        &mut memez_fun,
        mint_for_testing(first_purchase_value, world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(2),
        world.scenario.ctx(),
    ).burn_for_testing();

    destroy(memez_fun);

    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ETokenSupported, location = memez_fun)]
fun pump_use_token_instead() {
    let mut world = start();

    let first_purchase_value = 50_000_000_000;

    let total_supply = 1_000_000_000_000_000_000;

    let first_purchase = mint_for_testing(first_purchase_value, world.scenario.ctx());

    let mut memez_fun = set_up_pool(
        &mut world,
        first_purchase,
        true,
        total_supply,
    );

    memez_pump::pump(
        &mut memez_fun,
        mint_for_testing(first_purchase_value, world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    ).burn_for_testing();

    destroy(memez_fun);

    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ENotBonding, location = memez_fun)]
fun pump_is_not_bonding() {
    let mut world = start();

    let first_purchase_value = 10_000_000_000_000;

    let total_supply = 1_000_000_000_000_000_000;

    let first_purchase = mint_for_testing(add_fee(first_purchase_value, 30), world.scenario.ctx());

    let mut memez_fun = set_up_pool(
        &mut world,
        first_purchase,
        false,
        total_supply,
    );

    memez_pump::pump(
        &mut memez_fun,
        mint_for_testing(first_purchase_value, world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    ).burn_for_testing();

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
fun dump_invalid_version() {
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

    world.scenario.next_tx(DEAD_ADDRESS);

    let purchase_sui_value = 2_000 * POW_9;

    let ctx = world.scenario.ctx();

    let cp = memez_pump::constant_product_mut(&mut memez_fun);

    let swap_fee = cp.swap_fee().calculate(purchase_sui_value);

    let expected_meme_value = get_amount_out(
        purchase_sui_value - swap_fee,
        cp.virtual_liquidity() + cp.sui_balance().value(),
        cp.meme_balance().value(),
    );

    memez_pump::pump(
        &mut memez_fun,
        mint_for_testing(purchase_sui_value, ctx),
        expected_meme_value,
        memez_version::get_version_for_testing(1),
        ctx,
    ).burn_for_testing();

    world.scenario.next_tx(DEAD_ADDRESS);

    let mut treasury = world.scenario.take_shared<IPXTreasuryStandard>();

    let ctx = world.scenario.ctx();

    let sell_meme_value = expected_meme_value / 3;

    memez_pump::dump(
        &mut memez_fun,
        &mut treasury,
        mint_for_testing(sell_meme_value, ctx),
        0,
        memez_version::get_version_for_testing(2),
        ctx,
    ).burn_for_testing();

    destroy(memez_fun);
    destroy(treasury);

    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ETokenSupported, location = memez_fun)]
fun dump_use_token_instead() {
    let mut world = start();

    let first_purchase_value = 50_000_000_000;

    let total_supply = 1_000_000_000_000_000_000;

    let first_purchase = mint_for_testing(first_purchase_value, world.scenario.ctx());

    let mut memez_fun = set_up_pool(
        &mut world,
        first_purchase,
        true,
        total_supply,
    );

    world.scenario.next_tx(DEAD_ADDRESS);

    let mut treasury = world.scenario.take_shared<IPXTreasuryStandard>();

    let ctx = world.scenario.ctx();

    memez_pump::dump(
        &mut memez_fun,
        &mut treasury,
        mint_for_testing(100, ctx),
        0,
        memez_version::get_version_for_testing(1),
        ctx,
    ).burn_for_testing();

    destroy(memez_fun);
    destroy(treasury);

    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ENotBonding, location = memez_fun)]
fun dump_is_not_bonding() {
    let mut world = start();

    let first_purchase_value = 10_000_000_000_000;

    let total_supply = 1_000_000_000_000_000_000;

    let first_purchase = mint_for_testing(add_fee(first_purchase_value, 30), world.scenario.ctx());

    let mut memez_fun = set_up_pool(
        &mut world,
        first_purchase,
        false,
        total_supply,
    );

    world.scenario.next_tx(DEAD_ADDRESS);

    let mut treasury = world.scenario.take_shared<IPXTreasuryStandard>();

    let ctx = world.scenario.ctx();

    memez_pump::dump(
        &mut memez_fun,
        &mut treasury,
        mint_for_testing(100, ctx),
        0,
        memez_version::get_version_for_testing(1),
        ctx,
    ).burn_for_testing();

    destroy(memez_fun);
    destroy(treasury);

    world.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EOutdatedPackageVersion,
        location = memez_version,
    ),
]
fun migrate_invalid_version() {
    let mut world = start();

    let first_purchase_value = 10_000_000_000_000;

    let total_supply = 1_000_000_000_000_000_000;

    let first_purchase = mint_for_testing(first_purchase_value, world.scenario.ctx());

    let mut memez_fun = set_up_pool(
        &mut world,
        first_purchase,
        false,
        total_supply,
    );

    world.scenario.next_tx(DEAD_ADDRESS);

    let migrator = memez_pump::migrate(
        &mut memez_fun,
        memez_version::get_version_for_testing(2),
        world.scenario.ctx(),
    );

    destroy(migrator);
    destroy(memez_fun);

    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ENotMigrating, location = memez_fun)]
fun migrate_is_not_migrating() {
    let mut world = start();

    let first_purchase_value = 50_000_000_000;

    let total_supply = 1_000_000_000_000_000_000;

    let first_purchase = mint_for_testing(add_fee(first_purchase_value, 30), world.scenario.ctx());

    let mut memez_fun = set_up_pool(
        &mut world,
        first_purchase,
        false,
        total_supply,
    );

    world.scenario.next_tx(DEAD_ADDRESS);

    let migrator = memez_pump::migrate(
        &mut memez_fun,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    destroy(migrator);
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
fun dev_purchase_claim_invalid_version() {
    let mut world = start();

    let first_purchase_value = 10_000_000_000_000;

    let total_supply = 1_000_000_000_000_000_000;

    let first_purchase = mint_for_testing(add_fee(first_purchase_value, 30), world.scenario.ctx());

    let mut memez_fun = set_up_pool(
        &mut world,
        first_purchase,
        false,
        total_supply,
    );

    world.scenario.next_tx(DEAD_ADDRESS);

    let migrator = memez_pump::migrate(
        &mut memez_fun,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    let (sui_balance, meme_balance) = migrator.destroy(MigrationWitness());

    memez_pump::dev_purchase_claim(
        &mut memez_fun,
        memez_version::get_version_for_testing(2),
        world.scenario.ctx(),
    ).burn_for_testing();

    destroy(sui_balance);
    destroy(meme_balance);
    destroy(memez_fun);

    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ENotMigrated, location = memez_fun)]
fun dev_purchase_claim_has_not_migrated() {
    let mut world = start();

    let first_purchase_value = 10_000_000_000_000;

    let total_supply = 1_000_000_000_000_000_000;

    let first_purchase = mint_for_testing(add_fee(first_purchase_value, 30), world.scenario.ctx());

    let mut memez_fun = set_up_pool(
        &mut world,
        first_purchase,
        false,
        total_supply,
    );

    world.scenario.next_tx(ADMIN);

    memez_pump::dev_purchase_claim(
        &mut memez_fun,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    ).burn_for_testing();

    let migrator = memez_pump::migrate(
        &mut memez_fun,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    destroy(migrator);
    destroy(memez_fun);

    world.end();
}

#[test, expected_failure(abort_code = memez_errors::EInvalidDev, location = memez_fun)]
fun dev_purchase_claim_is_not_dev() {
    let mut world = start();

    let first_purchase_value = 10_000_000_000_000;

    let total_supply = 1_000_000_000_000_000_000;

    let first_purchase = mint_for_testing(add_fee(first_purchase_value, 30), world.scenario.ctx());

    let mut memez_fun = set_up_pool(
        &mut world,
        first_purchase,
        false,
        total_supply,
    );

    world.scenario.next_tx(DEAD_ADDRESS);

    let migrator = memez_pump::migrate(
        &mut memez_fun,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    let (sui_balance, meme_balance) = migrator.destroy(MigrationWitness());

    world.scenario.next_tx(DEAD_ADDRESS);

    memez_pump::dev_purchase_claim(
        &mut memez_fun,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    ).burn_for_testing();

    destroy(sui_balance);
    destroy(meme_balance);
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
fun pump_token_invalid_version() {
    let mut world = start();

    let first_purchase_value = 50_000_000_000;

    let total_supply = 1_000_000_000_000_000_000;

    let first_purchase = mint_for_testing(add_fee(first_purchase_value, 30), world.scenario.ctx());

    let mut memez_fun = set_up_pool(
        &mut world,
        first_purchase,
        true,
        total_supply,
    );

    memez_pump::pump_token(
        &mut memez_fun,
        mint_for_testing(first_purchase_value, world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(2),
        world.scenario.ctx(),
    ).burn_for_testing();

    destroy(memez_fun);

    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ETokenNotSupported, location = memez_fun)]
fun pump_use_coin_instead() {
    let mut world = start();

    let first_purchase_value = 50_000_000_000;

    let total_supply = 1_000_000_000_000_000_000;

    let first_purchase = mint_for_testing(add_fee(first_purchase_value, 30), world.scenario.ctx());

    let mut memez_fun = set_up_pool(
        &mut world,
        first_purchase,
        false,
        total_supply,
    );

    memez_pump::pump_token(
        &mut memez_fun,
        mint_for_testing(first_purchase_value, world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    ).burn_for_testing();

    destroy(memez_fun);

    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ENotBonding, location = memez_fun)]
fun pump_token_is_not_bonding() {
    let mut world = start();

    let first_purchase_value = 10_000_000_000_000;

    let total_supply = 1_000_000_000_000_000_000;

    let first_purchase = mint_for_testing(add_fee(first_purchase_value, 30), world.scenario.ctx());

    let mut memez_fun = set_up_pool(
        &mut world,
        first_purchase,
        true,
        total_supply,
    );

    memez_pump::pump_token(
        &mut memez_fun,
        mint_for_testing(first_purchase_value, world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    ).burn_for_testing();

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
fun dump_token_invalid_version() {
    let mut world = start();

    let first_purchase_value = 50_000_000_000;

    let total_supply = 1_000_000_000_000_000_000;

    let first_purchase = mint_for_testing(first_purchase_value * 10_000 / (10_000 - 30), world.scenario.ctx());

    let mut memez_fun = set_up_pool(
        &mut world,
        first_purchase,
        true,
        total_supply,
    );

    world.scenario.next_tx(DEAD_ADDRESS);

    let purchase_sui_value = 2_000 * POW_9;

    let ctx = world.scenario.ctx();

    let cp = memez_pump::constant_product_mut(&mut memez_fun);

    let swap_fee = cp.swap_fee().calculate(purchase_sui_value);

    let expected_meme_value = get_amount_out(
        purchase_sui_value - swap_fee,
        cp.virtual_liquidity() + cp.sui_balance().value(),
        cp.meme_balance().value(),
    );

    memez_pump::pump_token(
        &mut memez_fun,
        mint_for_testing(purchase_sui_value, ctx),
        expected_meme_value,
        memez_version::get_version_for_testing(1),
        ctx,
    ).burn_for_testing();

    world.scenario.next_tx(DEAD_ADDRESS);

    let mut treasury = world.scenario.take_shared<IPXTreasuryStandard>();

    let ctx = world.scenario.ctx();

    let sell_meme_value = expected_meme_value / 3;

    memez_pump::dump_token(
        &mut memez_fun,
        &mut treasury,
        token::mint_for_testing(sell_meme_value, ctx),
        0,
        memez_version::get_version_for_testing(2),
        ctx,
    ).burn_for_testing();

    destroy(memez_fun);
    destroy(treasury);

    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ETokenNotSupported, location = memez_fun)]
fun dump_use_coin_instead() {
    let mut world = start();

    let first_purchase_value = 50_000_000_000;

    let total_supply = 1_000_000_000_000_000_000;

    let first_purchase = mint_for_testing(first_purchase_value * 10_000 / (10_000 - 30), world.scenario.ctx());

    let mut memez_fun = set_up_pool(
        &mut world,
        first_purchase,
        false,
        total_supply,
    );

    world.scenario.next_tx(DEAD_ADDRESS);

    let mut treasury = world.scenario.take_shared<IPXTreasuryStandard>();

    let ctx = world.scenario.ctx();

    memez_pump::dump_token(
        &mut memez_fun,
        &mut treasury,
        token::mint_for_testing(100, ctx),
        0,
        memez_version::get_version_for_testing(1),
        ctx,
    ).burn_for_testing();

    destroy(memez_fun);
    destroy(treasury);

    world.end();
}

#[test, expected_failure(abort_code = memez_errors::ENotBonding, location = memez_fun)]
fun dump_token_is_not_bonding() {
    let mut world = start();

    let first_purchase_value = 10_000_000_000_000;

    let total_supply = 1_000_000_000_000_000_000;

    let first_purchase = mint_for_testing(add_fee((first_purchase_value * 10_000), 30), world.scenario.ctx());

    let mut memez_fun = set_up_pool(
        &mut world,
        first_purchase,
        true,
        total_supply,
    );

    world.scenario.next_tx(DEAD_ADDRESS);

    let mut treasury = world.scenario.take_shared<IPXTreasuryStandard>();

    let ctx = world.scenario.ctx();

    memez_pump::dump_token(
        &mut memez_fun,
        &mut treasury,
        token::mint_for_testing(100, ctx),
        0,
        memez_version::get_version_for_testing(1),
        ctx,
    ).burn_for_testing();

    destroy(memez_fun);
    destroy(treasury);

    world.end();
}

#[test]
fun test_distribute_stake_holders_allocation() {
    let mut world = start(); 

    let witness = acl::sign_in_for_testing();

    world.config
        .set_fees<DefaultKey>(
            &witness,
            vector[vector[MAX_BPS, 2 * POW_9], vector[MAX_BPS, 0, 30], vector[MAX_BPS, 0, 200 * POW_9], vector[MAX_BPS / 2, MAX_BPS / 2, VESTING_PERIOD, 500]],
            vector[vector[@0x0], vector[@0x0], vector[@0x0], vector[ADMIN]],
            world.scenario.ctx(),
        );
    
    let first_purchase = mint_for_testing(0, world.scenario.ctx());

    let total_supply = 1_000_000_000_000_000_000;

    let mut memez_fun = set_up_pool(
        &mut world,
        first_purchase,
        false,
        total_supply,
    );

    memez_pump::pump(
        &mut memez_fun,
        mint_for_testing(add_fee(TARGET_LIQUIDITY, 30), world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    ).burn_for_testing();

    let migrator = memez_pump::migrate(
        &mut memez_fun,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    let (sui_balance, meme_balance) = migrator.destroy(MigrationWitness());

    destroy(sui_balance);
    destroy(meme_balance);

    world.scenario.next_tx(ADMIN); 

    let mut clock = clock::create_for_testing(world.scenario.ctx());

    clock.increment_for_testing(VESTING_PERIOD);

    memez_pump::distribute_stake_holders_allocation(
        &mut memez_fun,
        &clock,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    world.scenario.next_tx(ADMIN); 

    let admin_vesting = world.scenario.take_from_address<MemezVesting<Meme>>(ADMIN);

    let stake_holder_vesting = world.scenario.take_from_address<MemezVesting<Meme>>(STAKE_HOLDER);

    let migration_fee = bps::new(500).calc_up(total_supply);

    assert_eq(admin_vesting.balance(), migration_fee / 2);
    assert_eq(stake_holder_vesting.balance(), migration_fee / 2);

    destroy(clock);

    destroy(memez_fun);

    destroy(admin_vesting);
    destroy(stake_holder_vesting);

    world.end();
}

#[test]
fun test_migrate_full_liquidity() {
    let mut world = start(); 

    let witness = acl::sign_in_for_testing();

    world.config
        .set_fees<DefaultKey>(
            &witness,
            vector[vector[MAX_BPS, 2 * POW_9], vector[MAX_BPS, 0, 30], vector[MAX_BPS, 0, 200 * POW_9], vector[MAX_BPS / 2, MAX_BPS / 2, VESTING_PERIOD, 0]],
            vector[vector[@0x0], vector[@0x0], vector[@0x0], vector[ADMIN]],
            world.scenario.ctx(),
        );

    world.config
        .set_pump<DefaultKey>(
            &witness,
            vector[0, VIRTUAL_LIQUIDITY, TARGET_LIQUIDITY, 0],
            world.scenario.ctx(),
        );

    let first_purchase = mint_for_testing(0, world.scenario.ctx());

    let total_supply = 1_000_000_000_000_000_000;

    let mut memez_fun = set_up_pool(
        &mut world,
        first_purchase,
        false,
        total_supply,
    );

    let cp = memez_pump::constant_product_mut(&mut memez_fun); 

    assert_eq(cp.meme_balance().value(), 1_000_000_000_000_000_000);

    memez_pump::pump(
        &mut memez_fun,
        mint_for_testing(add_fee(TARGET_LIQUIDITY, 30), world.scenario.ctx()),
        0,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    ).burn_for_testing();

    let migrator = memez_pump::migrate(
        &mut memez_fun,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    let cp = memez_pump::constant_product_mut(&mut memez_fun); 

    let expected_meme_balance = cp.meme_balance().value();

    let (sui_balance, meme_balance) = migrator.destroy(MigrationWitness());

    assert_eq(cp.meme_balance().value(), expected_meme_balance);

    destroy(sui_balance);
    destroy(meme_balance);

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
fun test_distribute_stake_holders_allocation_invalid_version() {
    let mut world = start();

    let first_purchase = mint_for_testing(0, world.scenario.ctx());

    let total_supply = 1_000_000_000_000_000_000;


    let mut memez_fun = set_up_pool(
        &mut world,
        first_purchase,
        false,
        total_supply,
    );

    let clock = clock::create_for_testing(world.scenario.ctx());

    memez_pump::distribute_stake_holders_allocation(
        &mut memez_fun,
        &clock,
        memez_version::get_version_for_testing(2),
        world.scenario.ctx(),
    );

    destroy(memez_fun);
    destroy(clock);

    world.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::ENotMigrated,
        location = memez_fun,
    ),
]
fun test_distribute_stake_holders_allocation_not_migrated() {
    let mut world = start();

    let first_purchase = mint_for_testing(0, world.scenario.ctx());

    let total_supply = 1_000_000_000_000_000_000;


    let mut memez_fun = set_up_pool(
        &mut world,
        first_purchase,
        false,
        total_supply,
    );

    let clock = clock::create_for_testing(world.scenario.ctx());

    memez_pump::distribute_stake_holders_allocation(
        &mut memez_fun,
        &clock,
        memez_version::get_version_for_testing(1),
        world.scenario.ctx(),
    );

    destroy(memez_fun);
    destroy(clock);

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

    let metadata_cap = memez_pump::new<Meme, DefaultKey, MigrationWitness>(
        &world.config,
        &world.migrator_list,
        create_treasury_cap_for_testing(ctx),
        mint_for_testing(2_000_000_000, ctx),
        total_supply,
        is_token,
        first_purchase,
        vector[],
        vector[],
        vector[STAKE_HOLDER],
        DEV,
        version,
        ctx,
    );

    destroy(metadata_cap);

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

    config
        .set_fees<DefaultKey>(
            &witness,
            vector[vector[MAX_BPS, 2 * POW_9], vector[MAX_BPS, 0, 30], vector[MAX_BPS, 0, 200 * POW_9], vector[MAX_BPS, 0, 0, 0]],
            vector[vector[ADMIN], vector[ADMIN], vector[ADMIN], vector[ADMIN]],
            scenario.ctx(),
        );

    config
        .set_pump<DefaultKey>(
            &witness,
            vector[BURN_TAX, VIRTUAL_LIQUIDITY, TARGET_LIQUIDITY, PROVISION_LIQUIDITY],
            scenario.ctx(),
        );

    World { config, migrator_list, scenario }
}

fun end(world: World) {
    destroy(world);
}
