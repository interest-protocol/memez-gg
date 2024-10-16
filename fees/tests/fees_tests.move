#[test_only]
module memez_fees::fees_tests;

use sui::{
    test_scenario::{Self, Scenario},
    test_utils::{destroy, assert_eq}
};

use memez_acl::acl::{Self, ACL, SuperAdmin, AuthWitness};

use memez_fees::memez_fees::{Self, MemezFees};

const ADMIN: address = @0x0;

// @dev 1%
const INITIAL_RATE: u64 = 10_000_000; 

// @dev 10%
const MAX_RATE: u64 = 100_000_000; 

public struct World {
    fees: MemezFees,
    witness: AuthWitness,
    scenario: Scenario,
}

public struct Rate1Key has copy, drop, store()

public struct Rate2Key has copy, drop, store()

// @dev 10^9
const PRECISION: u64 = 1__000_000_000;

#[test]
fun test_init() {
    let world = start();

    assert_eq(world.fees.treasury(), @treasury);

    end(world);
}

#[test]
fun test_view_functions() {
    let mut world = start();

    assert_eq(world.fees.has(Rate1Key()), false); 
    assert_eq(world.fees.has(Rate2Key()), false); 
    assert_eq(memez_fees::precision(), PRECISION);

    let witness = &world.witness;

    world.fees.add(witness, Rate1Key(), INITIAL_RATE);

    assert_eq(world.fees.rate(Rate1Key()).rate_value(), INITIAL_RATE);  
    assert_eq(world.fees.value(Rate1Key()), INITIAL_RATE);
    assert_eq(world.fees.has(Rate1Key()), true); 
    assert_eq(world.fees.has(Rate2Key()), false); 

    // 20 with 3 decimal houses
    let amount = 20_000;   

    // 0.2 with 3 decimal houses
    let expected_fee = 200; 

    assert_eq(expected_fee, world.fees.rate(Rate1Key()).calculate_fee(amount));
    assert_eq(amount, world.fees.rate(Rate1Key()).calculate_amount_in(amount - expected_fee));

    let amount = 77777123;   
    
    // rounds up
    let expected_fee = 777772; 

    assert_eq(expected_fee, world.fees.rate(Rate1Key()).calculate_fee(amount));
    assert_eq(amount, world.fees.rate(Rate1Key()).calculate_amount_in(amount - expected_fee));

    world.fees.add(witness, Rate2Key(), INITIAL_RATE * 3);

    assert_eq(world.fees.rate(Rate1Key()).rate_value(), INITIAL_RATE);  
    assert_eq(world.fees.value(Rate1Key()), INITIAL_RATE);
    assert_eq(world.fees.rate(Rate2Key()).rate_value(), INITIAL_RATE * 3);  
    assert_eq(world.fees.value(Rate2Key()), INITIAL_RATE * 3);
    assert_eq(world.fees.has(Rate1Key()), true); 
    assert_eq(world.fees.has(Rate2Key()), true); 

    // 20 with 3 decimal houses
    let amount = 20_000;   

    // 0.2 with 3 decimal houses
    let expected_fee = 200 * 3; 

    assert_eq(expected_fee, world.fees.rate(Rate2Key()).calculate_fee(amount));
    assert_eq(amount, world.fees.rate(Rate2Key()).calculate_amount_in(amount - expected_fee));

    let amount = 77777123;   
    
    // rounds up
    let expected_fee = (777771 * 3) + 1; 

    assert_eq(expected_fee, world.fees.rate(Rate2Key()).calculate_fee(amount));
    assert_eq(amount, world.fees.rate(Rate2Key()).calculate_amount_in(amount - expected_fee));    

    world.end();
}

#[test]
fun test_admin_functions() {
    let mut world = start(); 

    let witness = &world.witness;

    world.fees.add(witness, Rate1Key(), INITIAL_RATE);

    assert_eq(world.fees.value(Rate1Key()), INITIAL_RATE);
    assert_eq(world.fees.treasury(), @treasury);

    world.fees.add(witness, Rate1Key(), INITIAL_RATE * 3);
    world.fees.set_treasury(witness, ADMIN);

    assert_eq(world.fees.value(Rate1Key()), INITIAL_RATE * 3);
    assert_eq(world.fees.treasury(), ADMIN);

    assert_eq(world.fees.has(Rate1Key()), true); 

    world.fees.remove(witness, Rate1Key()); 

    assert_eq(world.fees.has(Rate1Key()), false); 

    world.end();
}

#[test]
#[expected_failure(abort_code = memez_fees::EFeeIsTooHigh)]
fun test_set_fee_too_high() {
    let mut world = start(); 

    let witness = &world.witness;

    world.fees.add(witness, Rate1Key(), MAX_RATE + 1);

    world.end();
}

fun start(): World {
    let mut scenario = test_scenario::begin(ADMIN);

    acl::init_for_testing(scenario.ctx()); 
    memez_fees::init_for_testing(scenario.ctx()); 

    scenario.next_tx(ADMIN); 

    let super_admin = scenario.take_from_sender<SuperAdmin>(); 

    let mut acl = scenario.take_shared<ACL>();  

    let admin = acl.new(&super_admin, scenario.ctx()); 

    let auth_witness = acl.sign_in(&admin);  

    let fees = scenario.take_shared<MemezFees>(); 

    destroy(super_admin); 
    destroy(acl); 
    destroy(admin); 

    World {
        fees,
        witness: auth_witness,
        scenario,
    }
}

fun end(world: World) {
    destroy(world);
}