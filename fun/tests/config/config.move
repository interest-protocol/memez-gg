#[test_only]
module memez_fun::memez_config_tests;

use ipx_coin_standard::ipx_coin_standard::IPXTreasuryStandard;
use memez_acl::acl;
use memez_fun::{gg::{Self, GG}, memez_config::{Self, MemezConfig}};
use sui::{
    coin::{TreasuryCap, Coin, mint_for_testing},
    sui::SUI,
    test_scenario::{Self as ts, Scenario},
    test_utils::{assert_eq, destroy}
};

const ADMIN: address = @0x1;

const CREATION_FEE: u64 = 2__000_000_000;

const MIGRATION_FEE: u64 = 200__000_000_000;

const TOTAL_MEME_SUPPLY: u64 = 1_000_000_000__000_000_000;

const TREASURY: address = @0xdd224f2287f0b38693555c6077abe85fcb4aa13e355ad54bc167611896b007e6;

public struct World {
    scenario: Scenario,
    config: MemezConfig,
    treasury_cap: vector<TreasuryCap<GG>>,
}

#[test]
fun test_init() {
    let world = start();

    assert_eq(memez_config::treasury(&world.config), TREASURY);
    assert_eq(memez_config::creation_fee(&world.config), CREATION_FEE);
    assert_eq(memez_config::migration_fee(&world.config), MIGRATION_FEE);

    world.end();
}

#[test]
fun test_setters() {
    let mut world = start();

    let witness = acl::sign_in_for_testing();

    world.config.set_creation_fee(&witness, CREATION_FEE * 3);
    world.config.set_migration_fee(&witness, MIGRATION_FEE * 2);
    world.config.set_treasury(&witness, @0x0);

    assert_eq(memez_config::creation_fee(&world.config), CREATION_FEE * 3);
    assert_eq(memez_config::migration_fee(&world.config), MIGRATION_FEE * 2);
    assert_eq(memez_config::treasury(&world.config), @0x0);

    world.end();
}

#[test]
fun set_up_treasury() {
    let mut world = start();

    let treasury_cap = world.treasury_cap.pop_back();

    let (meme_treasury_address, metadata_cap, meme_balance) = memez_config::set_up_meme_treasury(
        treasury_cap,
        TOTAL_MEME_SUPPLY,
        world.scenario.ctx(),
    );

    world.scenario.next_epoch(ADMIN);

    let meme_treasury = world.scenario.take_shared<IPXTreasuryStandard>();

    assert_eq(object::id(&meme_treasury).to_address(), meme_treasury_address);

    assert_eq(metadata_cap.treasury(), meme_treasury_address);
    assert_eq(meme_balance.value(), TOTAL_MEME_SUPPLY);
    assert_eq(meme_treasury.total_supply<GG>(), TOTAL_MEME_SUPPLY);
    assert_eq(meme_treasury.can_burn(), true);

    destroy(meme_balance);
    destroy(meme_treasury);
    metadata_cap.destroy();
    world.end();
}

#[test, expected_failure(abort_code = memez_config::EPreMint)]
fun set_up_treasury_pre_mint() {
    let mut world = start();

    let mut treasury_cap = world.treasury_cap.pop_back();

    treasury_cap.mint(100, world.scenario.ctx()).burn_for_testing();

    let (_, metadata_cap, meme_balance) = memez_config::set_up_meme_treasury(
        treasury_cap,
        TOTAL_MEME_SUPPLY,
        world.scenario.ctx(),
    );

    destroy(meme_balance);
    metadata_cap.destroy();
    world.end();
}

#[test]
fun test_take_fees() {
    let mut world = start();

    world.config.take_creation_fee(mint_for_testing(CREATION_FEE, world.scenario.ctx()));

    world.scenario.next_epoch(ADMIN);

    let creation_fee_coin = world.scenario.take_from_address<Coin<SUI>>(TREASURY);

    assert_eq(creation_fee_coin.burn_for_testing(), CREATION_FEE);

    world.config.take_migration_fee(mint_for_testing(MIGRATION_FEE, world.scenario.ctx()));

    world.scenario.next_epoch(ADMIN);

    let migration_fee_coin = world.scenario.take_from_address<Coin<SUI>>(TREASURY);

    assert_eq(migration_fee_coin.burn_for_testing(), MIGRATION_FEE);

    world.end();
}

#[test, expected_failure(abort_code = memez_config::ENotEnoughSuiForCreationFee)]
fun test_take_creation_fee_wrong_value() {
    let mut world = start();

    world.config.take_creation_fee(mint_for_testing(CREATION_FEE - 1, world.scenario.ctx()));

    world.end();
}

#[test, expected_failure(abort_code = memez_config::ENotEnoughSuiForMigrationFee)]
fun test_take_migration_fee_wrong_value() {
    let mut world = start();

    world.config.take_migration_fee(mint_for_testing(MIGRATION_FEE - 1, world.scenario.ctx()));

    world.end();
}

fun start(): World {
    let mut scenario = ts::begin(ADMIN);

    memez_config::init_for_testing(scenario.ctx());
    gg::init_for_testing(scenario.ctx());

    scenario.next_epoch(ADMIN);

    let config = scenario.take_shared<MemezConfig>();
    let treasury_cap = scenario.take_from_sender<TreasuryCap<GG>>();

    World {
        scenario,
        config,
        treasury_cap: vector[treasury_cap],
    }
}

fun end(world: World) {
    destroy(world);
}
