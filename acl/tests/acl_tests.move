#[test_only]
module memez_acl::memez_acl_tests;

use memez_acl::acl::{Self, MemezACL, MemezSuperAdmin};
use std::u64;
use sui::{test_scenario::{Self, Scenario}, test_utils::{destroy, assert_eq}};

const ADMIN: address = @0xa11ce;
const NEW_ADMIN: address = @0xdead;

public struct World {
    scenario: Scenario,
    acl: MemezACL,
    super_admin: MemezSuperAdmin,
}

#[test]
fun test_init() {
    let world = start();

    assert_eq(world.super_admin.new_admin(), @0x0);
    assert_eq(world.super_admin.start(), u64::max_value!());
    assert_eq(world.acl.admins().size(), 0);

    world.end();
}

#[test]
fun test_new() {
    let mut world = start();

    let super_admin = &world.super_admin;

    assert_eq(world.acl.admins().size(), 0);

    let admin = world.acl.new(super_admin, world.scenario.ctx());

    assert_eq(world.acl.admins().size(), 1);
    assert_eq(world.acl.is_admin(admin.addy()), true);

    world.acl.destroy_admin(admin);

    world.end();
}

#[test]
fun test_revoke() {
    let mut world = start();

    let super_admin = &world.super_admin;

    assert_eq(world.acl.admins().size(), 0);

    let admin = world.acl.new(super_admin, world.scenario.ctx());

    assert_eq(world.acl.admins().size(), 1);
    assert_eq(world.acl.is_admin(admin.addy()), true);

    world.acl.revoke(super_admin, admin.addy());

    assert_eq(world.acl.admins().size(), 0);
    assert_eq(world.acl.is_admin(admin.addy()), false);

    world.acl.destroy_admin(admin);

    world.end();
}

#[test]
fun test_sign_in() {
    let mut world = start();

    let super_admin = &world.super_admin;

    assert_eq(world.acl.admins().size(), 0);

    let admin = world.acl.new(super_admin, world.scenario.ctx());

    assert_eq(world.acl.admins().size(), 1);
    assert_eq(world.acl.is_admin(admin.addy()), true);

    let _witness = world.acl.sign_in(&admin);

    world.acl.destroy_admin(admin);

    world.end();
}

#[test]
fun test_super_admin_transfer() {
    let mut world = start();

    assert_eq(world.super_admin.new_admin(), @0x0);
    assert_eq(world.super_admin.start(), u64::max_value!());

    world.scenario.next_epoch(ADMIN);
    world.scenario.next_epoch(ADMIN);

    world.super_admin.start_transfer(NEW_ADMIN, world.scenario.ctx());

    assert_eq(world.super_admin.new_admin(), NEW_ADMIN);
    assert_eq(world.super_admin.start(), 2);

    world.scenario.next_epoch(ADMIN);
    world.scenario.next_epoch(ADMIN);
    world.scenario.next_epoch(ADMIN);
    world.scenario.next_epoch(ADMIN);

    let World { mut scenario, acl, super_admin } = world;

    super_admin.finish_transfer(scenario.ctx());

    scenario.next_tx(NEW_ADMIN);

    let super_admin = scenario.take_from_sender<MemezSuperAdmin>();

    assert_eq(super_admin.new_admin(), @0x0);
    assert_eq(super_admin.start(), u64::max_value!());

    destroy(acl);
    destroy(scenario);
    destroy(super_admin);
}

#[test]
#[expected_failure(abort_code = acl::InvalidNewSuperAdmin)]
fun test_super_admin_transfer_error_same_sender() {
    let mut world = start();

    assert_eq(world.super_admin.new_admin(), @0x0);
    assert_eq(world.super_admin.start(), u64::max_value!());

    world.super_admin.start_transfer(ADMIN, world.scenario.ctx());

    world.end();
}

#[test]
#[expected_failure(abort_code = acl::InvalidNewSuperAdmin)]
fun test_super_admin_transfer_error_zero_address() {
    let mut world = start();

    assert_eq(world.super_admin.new_admin(), @0x0);
    assert_eq(world.super_admin.start(), u64::max_value!());

    world.super_admin.start_transfer(@0x0, world.scenario.ctx());

    world.end();
}

#[test]
#[expected_failure(abort_code = acl::InvalidEpoch)]
fun test_super_admin_finish_transfer_invalid_epoch() {
    let mut world = start();

    world.super_admin.start_transfer(NEW_ADMIN, world.scenario.ctx());

    world.scenario.next_epoch(ADMIN);
    world.scenario.next_epoch(ADMIN);
    world.scenario.next_epoch(ADMIN);

    let World { mut scenario, acl, super_admin } = world;

    super_admin.finish_transfer(scenario.ctx());

    scenario.next_tx(NEW_ADMIN);

    let super_admin = scenario.take_from_sender<MemezSuperAdmin>();

    assert_eq(super_admin.new_admin(), @0x0);
    assert_eq(super_admin.start(), u64::max_value!());

    destroy(acl);
    destroy(scenario);
    destroy(super_admin);
}

#[test]
#[expected_failure(abort_code = acl::InvalidAdmin)]
fun test_sign_in_error_invalid_admin() {
    let mut world = start();

    let super_admin = &world.super_admin;

    assert_eq(world.acl.admins().size(), 0);

    let admin = world.acl.new(super_admin, world.scenario.ctx());

    world.acl.revoke(super_admin, admin.addy());

    let _witness = world.acl.sign_in(&admin);

    world.acl.destroy_admin(admin);

    world.end();
}

fun start(): World {
    let mut scenario = test_scenario::begin(ADMIN);

    acl::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let acl = scenario.take_shared<MemezACL>();
    let super_admin = scenario.take_from_sender<MemezSuperAdmin>();

    World {
        scenario,
        acl,
        super_admin,
    }
}

fun end(world: World) {
    destroy(world)
}
