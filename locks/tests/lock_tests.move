#[test_only]
module memez_locks::lock_tests;

use sui::{
    test_utils::{assert_eq, destroy},
    test_scenario::{Self as ts, Scenario}
};

use memez_acl::acl::{Self, ACL, SuperAdmin};

use memez_fees::memez_fees::{Self, MemezFees};

use memez_locks::lock;

const ADMIN: address = @0xdead;

// @dev 5%
const FEE: u64 = 50_000_000; 

public struct Position has key, store {
    id: UID,
    value: u64
}

public struct World {
    fees: MemezFees, 
    scenario: Scenario
}

#[test]
fun test_end_to_end() {
    let mut world = start();  

    let mut lock = lock::new(       
        &world.fees,
        Position {
            id: object::new(world.scenario.ctx()),
            value: 100
        },
        10,
        world.scenario.ctx()
    );

    assert_eq(lock.rate().rate_value(), FEE);
    assert_eq(lock.unlock_epoch(), 10); 
    assert_eq(lock.treasury(), world.fees.treasury()); 

    let (amount_a, amount_b) = lock.amounts(); 

    assert_eq(amount_a, 0);
    assert_eq(amount_b, 0);

    let (total_fees_a, total_fees_b) = lock.total_fees(); 

    assert_eq(total_fees_a, 0);
    assert_eq(total_fees_b, 0);

    let (total_admin_fees_a, total_admin_fees_b) = lock.total_admin_fees(); 

    assert_eq(total_admin_fees_a, 0);
    assert_eq(total_admin_fees_b, 0);

    let position = lock.borrow<Position>(); 

    assert_eq(position.value, 100);

    let position_mut = lock.borrow_mut<Position>(); 

    position_mut.value = 200; 

    let position = lock.borrow<Position>(); 

    assert_eq(position.value, 200);

    lock.add_fees(10, 10);

    let (total_fees_a, total_fees_b) = lock.total_fees(); 

    assert_eq(total_fees_a, 10);
    assert_eq(total_fees_b, 10);

    let (total_admin_fees_a, total_admin_fees_b) = lock.total_admin_fees(); 

    assert_eq(total_admin_fees_a, 0);
    assert_eq(total_admin_fees_b, 0);

    lock.add_admin_fees(12, 12);
    lock.add_admin_fees(12, 12);

    let (total_admin_fees_a, total_admin_fees_b) = lock.total_admin_fees(); 

    assert_eq(total_admin_fees_a, 24);
    assert_eq(total_admin_fees_b, 24);

    lock.add_amounts(100, 100);

    let (amount_a, amount_b) = lock.amounts(); 

    assert_eq(amount_a, 100);
    assert_eq(amount_b, 100);

    lock.add_amounts(100, 100);

    let (amount_a, amount_b) = lock.amounts(); 

    assert_eq(amount_a, 200);
    assert_eq(amount_b, 200); 

    lock.add_fees(10, 10);

    let (total_fees_a, total_fees_b) = lock.total_fees(); 

    assert_eq(total_fees_a, 20);
    assert_eq(total_fees_b, 20);

    world.scenario.next_epoch(ADMIN);
    world.scenario.next_epoch(ADMIN);
    world.scenario.next_epoch(ADMIN);
    world.scenario.next_epoch(ADMIN);
    world.scenario.next_epoch(ADMIN);
    world.scenario.next_epoch(ADMIN);
    world.scenario.next_epoch(ADMIN);
    world.scenario.next_epoch(ADMIN);
    world.scenario.next_epoch(ADMIN);
    world.scenario.next_epoch(ADMIN);
    world.scenario.next_epoch(ADMIN);

    let position = lock.destroy<Position>(world.scenario.ctx());
    
    let Position { id, .. } = position; 

    id.delete();

    world.end();
}

#[test]
#[expected_failure(abort_code = lock::EInvalidEpoch)]
fun test_invalid_epoch() {
    let mut world = start();  

    world.scenario.next_epoch(ADMIN);

    let lock = lock::new(       
        &world.fees,
        Position {
            id: object::new(world.scenario.ctx()),
            value: 100
        },
        1,
        world.scenario.ctx()
    );

    destroy(lock);
    world.end();
}

#[test]
#[expected_failure(abort_code = lock::EPositionLocked)]
fun test_position_locked() {
    let mut world = start();  

    let lock = lock::new(       
        &world.fees,
        Position {
            id: object::new(world.scenario.ctx()),
            value: 100
        },
        1,
        world.scenario.ctx()
    );

    world.scenario.next_epoch(ADMIN);

    destroy(lock.destroy<Position>(world.scenario.ctx()));

    world.end();
}

fun start(): World {
    let mut scenario = ts::begin(ADMIN); 

    acl::init_for_testing(scenario.ctx());
    memez_fees::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let super_admin = scenario.take_from_sender<SuperAdmin>(); 

    let mut acl = scenario.take_shared<ACL>();  

    let admin = acl.new(&super_admin, scenario.ctx()); 

    let auth_witness = acl.sign_in(&admin);  

    let mut fees = scenario.take_shared<MemezFees>(); 

    destroy(super_admin); 
    destroy(acl); 
    destroy(admin); 

    lock::set_fee(&mut fees, &auth_witness, FEE);

    World {
        fees, 
        scenario
    }
}

fun end(world: World) {
    destroy(world);
}