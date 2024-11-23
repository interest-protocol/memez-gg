#[test_only]
module memez_fun::version_tests;

use memez_acl::acl;
use memez_fun::{memez_errors, memez_version::{Self, Version}};
use sui::{test_scenario::{Self as ts, Scenario}, test_utils::{assert_eq, destroy}};

const ADMIN: address = @0x1;

public struct World {
    scenario: Scenario,
    version: Version,
}

#[test]
fun test_init() {
    let world = start();

    assert_eq(world.version.version(), 1);

    end(world);
}

#[test]
fun test_update() {
    let mut world = start();

    let witness = acl::sign_in_for_testing();

    world.version.update(&witness);

    assert_eq(world.version.version(), 2);

    end(world);
}

#[test]
fun test_assert_is_valid() {
    let world = start();

    let current_version = world.version.get_version();

    current_version.assert_is_valid();

    end(world);
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EOutdatedPackageVersion,
        location = memez_version,
    ),
]
fun test_assert_is_invalid() {
    let mut world = start();

    let current_version = world.version.get_version();

    current_version.assert_is_valid();

    let witness = acl::sign_in_for_testing();

    world.version.update(&witness);

    assert_eq(world.version.version(), 2);

    let current_version = world.version.get_version();

    current_version.assert_is_valid();

    end(world);
}

fun start(): World {
    let mut scenario = ts::begin(ADMIN);

    memez_version::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let version = scenario.take_shared<Version>();

    World { scenario, version }
}

fun end(world: World) {
    destroy(world);
}
