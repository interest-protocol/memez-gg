#[test_only]
module memez_fun::version_tests;

use interest_access_control::access_control;
use memez::memez::MEMEZ;
use memez_fun::{memez_allowed_versions::{Self, MemezAV}, memez_errors};
use sui::{test_scenario::{Self as ts, Scenario}, test_utils::{assert_eq, destroy}};

const ADMIN: address = @0x1;

public struct World {
    scenario: Scenario,
    av: MemezAV,
}

#[test]
fun test_init() {
    let world = start();

    assert_eq(world.av.allowed_versions(), vector[2]);

    end(world);
}

#[test]
fun test_admin_functions() {
    let mut world = start();

    let witness = access_control::sign_in_for_testing<MEMEZ>(0);

    assert_eq(world.av.allowed_versions(), vector[2]);

    world.av.add(&witness, 1);

    world.av.add(&witness, 3);

    assert_eq(world.av.allowed_versions(), vector[2, 1, 3]);

    world.av.remove(&witness, 1);

    assert_eq(world.av.allowed_versions(), vector[2, 3]);

    end(world);
}

#[test]
fun test_assert_pkg_version() {
    let mut world = start();

    world.av.get_allowed_versions().assert_pkg_version();

    let witness = access_control::sign_in_for_testing<MEMEZ>(0);

    world.av.add(&witness, 1);

    memez_allowed_versions::get_allowed_versions_for_testing(2).assert_pkg_version();

    end(world);
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EOutdatedPackageVersion,
        location = memez_allowed_versions,
    ),
]
fun test_outdated_package_version() {
    let mut world = start();

    let current_version = world.av.get_allowed_versions();

    current_version.assert_pkg_version();

    world.av.remove_for_testing(2);

    let witness = access_control::sign_in_for_testing<MEMEZ>(0);

    world.av.add(&witness, 1);

    assert_eq(world.av.allowed_versions(), vector[1]);

    world.av.get_allowed_versions().assert_pkg_version();

    end(world);
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::ERemoveCurrentVersionNotAllowed,
        location = memez_allowed_versions,
    ),
]
fun test_remove_current_version_not_allowed() {
    let mut world = start();

    let witness = access_control::sign_in_for_testing<MEMEZ>(0);

    world.av.remove(&witness, 2);

    end(world);
}

fun start(): World {
    let mut scenario = ts::begin(ADMIN);

    memez_allowed_versions::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let av = scenario.take_shared<MemezAV>();

    World { scenario, av }
}

fun end(world: World) {
    destroy(world);
}
