module memez_fun::memez_migrator_tests;

use memez_acl::acl;
use memez_fun::memez_migrator_list::{Self, MemezMigratorList};
use std::type_name;
use sui::{test_scenario::{Self as ts, Scenario}, test_utils::{assert_eq, destroy}};

const ADMIN: address = @0x1;

public struct MemezDex has drop ()

public struct Cetus has drop ()

public struct World {
    scenario: Scenario,
    migrator: MemezMigratorList,
}

#[test]
fun test_init() {
    let world = start();

    let whitelist = memez_migrator_list::whitelisted(&world.migrator);

    assert_eq(whitelist.is_empty(), true);

    end(world);
}

#[test]
fun test_admin_setters() {
    let mut world = start();

    let witness = acl::sign_in_for_testing();

    let whitelist = memez_migrator_list::whitelisted(&world.migrator);

    assert_eq(whitelist.is_empty(), true);

    world.migrator.add<MemezDex>(&witness);

    let whitelist = memez_migrator_list::whitelisted(&world.migrator);

    assert_eq(whitelist.contains(&type_name::get<MemezDex>()), true);
    assert_eq(!whitelist.contains(&type_name::get<Cetus>()), true);

    world.migrator.assert_is_whitelisted(type_name::get<MemezDex>());

    world.migrator.remove<MemezDex>(&witness);

    let whitelist = memez_migrator_list::whitelisted(&world.migrator);

    assert_eq(whitelist.is_empty(), true);

    end(world);
}

#[test, expected_failure(abort_code = memez_migrator_list::EInvalidWitness)]
fun test_assert_is_whitelisted() {
    let world = start();

    world.migrator.assert_is_whitelisted(type_name::get<Cetus>());

    world.end();
}

fun start(): World {
    let mut scenario = ts::begin(ADMIN);

    memez_migrator_list::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let migrator = scenario.take_shared<MemezMigratorList>();

    World { scenario, migrator }
}

fun end(world: World) {
    destroy(world);
}
