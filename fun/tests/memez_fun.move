#[test_only]
module memez_fun::memez_fun_tests;

use memez_acl::acl;
use memez_fun::{memez_errors, memez_fun, memez_migrator_list::{Self, MemezMigratorList}};
use std::type_name;
use sui::{
    balance,
    test_scenario::{Self as ts, Scenario},
    test_utils::{assert_eq, destroy},
    versioned::{Self, Versioned}
};

const ADMIN: address = @0x1;

public struct Curve has drop ()

public struct Meme has drop ()

public struct MigrationWitness has drop ()

public struct World {
    scenario: Scenario,
    migrator_list: MemezMigratorList,
    versioned: vector<Versioned>,
}

#[test]
fun test_new() {
    let mut world = start();

    let versioned = world.versioned.pop_back();

    let memez_fun = memez_fun::new<Curve, MigrationWitness, Meme>(
        &world.migrator_list,
        versioned,
        false,
        vector[b"Twitter".to_string()],
        vector[b"https://twitter.com/memez".to_string()],
        @0x7,
        world.scenario.ctx(),
    );

    let memez_fun_address = memez_fun.addy();

    assert_eq(memez_fun_address, object::id_address(&memez_fun));
    assert_eq(memez_fun.migration_witness(), type_name::get<MigrationWitness>());
    assert_eq(memez_fun.dev(), ADMIN);
    assert_eq(memez_fun.ip_meme_coin_treasury(), @0x7);
    assert_eq(
        *memez_fun.metadata().get(&b"Twitter".to_string()),
        b"https://twitter.com/memez".to_string(),
    );
    memez_fun.assert_is_bonding();

    memez_fun.share();
    end(world);
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EInvalidWitness,
        location = memez_migrator_list,
    ),
]
fun test_new_invalid_witness() {
    let mut world = start();

    let versioned = world.versioned.pop_back();

    let memez_fun = memez_fun::new<Curve, Meme, Meme>(
        &world.migrator_list,
        versioned,
        false,
        vector[b"Twitter".to_string()],
        vector[b"https://twitter.com/memez".to_string()],
        @0x7,
        world.scenario.ctx(),
    );

    memez_fun.share();
    end(world);
}

#[test, expected_failure(abort_code = memez_errors::ENotBonding, location = memez_fun)]
fun test_progress_asserts_not_bonding() {
    let mut world = start();

    let versioned = world.versioned.pop_back();

    let mut memez_fun = memez_fun::new<Curve, MigrationWitness, Meme>(
        &world.migrator_list,
        versioned,
        false,
        vector[b"Twitter".to_string()],
        vector[b"https://twitter.com/memez".to_string()],
        @0x7,
        world.scenario.ctx(),
    );

    memez_fun.set_progress_to_migrating();

    memez_fun.assert_is_bonding();

    abort
}

#[test, expected_failure(abort_code = memez_errors::ENotMigrating, location = memez_fun)]
fun test_progress_asserts_not_migrating() {
    let mut world = start();

    let versioned = world.versioned.pop_back();

    let memez_fun = memez_fun::new<Curve, MigrationWitness, Meme>(
        &world.migrator_list,
        versioned,
        false,
        vector[b"Twitter".to_string()],
        vector[b"https://twitter.com/memez".to_string()],
        @0x7,
        world.scenario.ctx(),
    );

    memez_fun.assert_is_migrating();

    abort
}

#[test, expected_failure(abort_code = memez_errors::ENotMigrated, location = memez_fun)]
fun test_progress_asserts_not_migrated() {
    let mut world = start();

    let versioned = world.versioned.pop_back();

    let memez_fun = memez_fun::new<Curve, MigrationWitness, Meme>(
        &world.migrator_list,
        versioned,
        false,
        vector[b"Twitter".to_string()],
        vector[b"https://twitter.com/memez".to_string()],
        @0x7,
        world.scenario.ctx(),
    );

    memez_fun.assert_migrated();

    abort
}

#[test]
fun test_assert_is_dev() {
    let mut world = start();

    let versioned = world.versioned.pop_back();

    let memez_fun = memez_fun::new<Curve, MigrationWitness, Meme>(
        &world.migrator_list,
        versioned,
        false,
        vector[b"Twitter".to_string()],
        vector[b"https://twitter.com/memez".to_string()],
        @0x7,
        world.scenario.ctx(),
    );

    world.scenario.next_tx(ADMIN);

    memez_fun.assert_is_dev(world.scenario.ctx());

    destroy(memez_fun);
    world.end();
}

#[test, expected_failure(abort_code = memez_errors::EInvalidDev, location = memez_fun)]
fun test_assert_is_dev_invalid_dev() {
    let mut world = start();

    let versioned = world.versioned.pop_back();

    let memez_fun = memez_fun::new<Curve, MigrationWitness, Meme>(
        &world.migrator_list,
        versioned,
        false,
        vector[b"Twitter".to_string()],
        vector[b"https://twitter.com/memez".to_string()],
        @0x7,
        world.scenario.ctx(),
    );

    world.scenario.next_tx(@0x0);

    memez_fun.assert_is_dev(world.scenario.ctx());

    abort
}

#[test]
fun test_assert_uses_token() {
    let mut world = start();

    let versioned = world.versioned.pop_back();

    let memez_fun = memez_fun::new<Curve, MigrationWitness, Meme>(
        &world.migrator_list,
        versioned,
        true,
        vector[b"Twitter".to_string()],
        vector[b"https://twitter.com/memez".to_string()],
        @0x7,
        world.scenario.ctx(),
    );

    world.scenario.next_tx(@0x0);

    memez_fun.assert_uses_token();

    destroy(memez_fun);
    end(world);
}

#[test]
fun test_assert_uses_coin() {
    let mut world = start();

    let versioned = world.versioned.pop_back();

    let memez_fun = memez_fun::new<Curve, MigrationWitness, Meme>(
        &world.migrator_list,
        versioned,
        false,
        vector[b"Twitter".to_string()],
        vector[b"https://twitter.com/memez".to_string()],
        @0x7,
        world.scenario.ctx(),
    );

    world.scenario.next_tx(@0x0);

    memez_fun.assert_uses_coin();

    destroy(memez_fun);
    end(world);
}

#[test, expected_failure(abort_code = memez_errors::ETokenSupported, location = memez_fun)]
fun test_assert_uses_coin_invalid() {
    let mut world = start();

    let versioned = world.versioned.pop_back();

    let memez_fun = memez_fun::new<Curve, MigrationWitness, Meme>(
        &world.migrator_list,
        versioned,
        true,
        vector[b"Twitter".to_string()],
        vector[b"https://twitter.com/memez".to_string()],
        @0x7,
        world.scenario.ctx(),
    );

    world.scenario.next_tx(@0x0);

    memez_fun.assert_uses_coin();

    abort
}

#[test, expected_failure(abort_code = memez_errors::ETokenNotSupported, location = memez_fun)]
fun test_assert_uses_token_invalid() {
    let mut world = start();

    let versioned = world.versioned.pop_back();

    let memez_fun = memez_fun::new<Curve, MigrationWitness, Meme>(
        &world.migrator_list,
        versioned,
        false,
        vector[b"Twitter".to_string()],
        vector[b"https://twitter.com/memez".to_string()],
        @0x7,
        world.scenario.ctx(),
    );

    world.scenario.next_tx(@0x0);

    memez_fun.assert_uses_token();

    destroy(memez_fun);
    end(world);
}

#[test]
fun test_progress_asserts() {
    let mut world = start();

    let versioned = world.versioned.pop_back();

    let mut memez_fun = memez_fun::new<Curve, MigrationWitness, Meme>(
        &world.migrator_list,
        versioned,
        false,
        vector[b"Twitter".to_string()],
        vector[b"https://twitter.com/memez".to_string()],
        @0x7,
        world.scenario.ctx(),
    );

    memez_fun.assert_is_bonding();

    memez_fun.set_progress_to_migrating();

    memez_fun.assert_is_migrating();

    let migrator = memez_fun.migrate(balance::zero(), balance::zero());

    memez_fun.assert_migrated();

    memez_fun.share();
    destroy(migrator);
    end(world);
}

#[test]
fun test_migrate() {
    let mut world = start();

    let versioned = world.versioned.pop_back();

    let mut memez_fun = memez_fun::new<Curve, MigrationWitness, Meme>(
        &world.migrator_list,
        versioned,
        false,
        vector[b"Twitter".to_string()],
        vector[b"https://twitter.com/memez".to_string()],
        @0x7,
        world.scenario.ctx(),
    );

    let migrator = memez_fun.migrate(
        balance::create_for_testing(1000),
        balance::create_for_testing(2000),
    );

    let (sui_balance, meme_balance) = migrator.destroy(MigrationWitness());

    assert_eq(meme_balance.value(), 2000);
    assert_eq(sui_balance.value(), 1000);

    memez_fun.share();

    destroy(meme_balance);
    destroy(sui_balance);
    end(world);
}

#[test, expected_failure(abort_code = memez_errors::EInvalidWitness, location = memez_fun)]
fun test_migrate_invalid_witness() {
    let mut world = start();

    let versioned = world.versioned.pop_back();

    let mut memez_fun = memez_fun::new<Curve, MigrationWitness, Meme>(
        &world.migrator_list,
        versioned,
        false,
        vector[b"Twitter".to_string()],
        vector[b"https://twitter.com/memez".to_string()],
        @0x7,
        world.scenario.ctx(),
    );

    let migrator = memez_fun.migrate(
        balance::create_for_testing(1000),
        balance::create_for_testing(2000),
    );

    let (sui_balance, meme_balance) = migrator.destroy(Meme());

    memez_fun.share();

    destroy(meme_balance);
    destroy(sui_balance);
    end(world);
}

fun start(): World {
    let mut scenario = ts::begin(ADMIN);

    memez_migrator_list::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let mut migrator_list = scenario.take_shared<MemezMigratorList>();

    let witness = acl::sign_in_for_testing();

    migrator_list.add<MigrationWitness>(&witness);

    let versioned = versioned::create(1, 10, scenario.ctx());

    World { scenario, migrator_list, versioned: vector[versioned] }
}

fun end(world: World) {
    destroy(world);
}
