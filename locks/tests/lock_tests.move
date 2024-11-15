#[test_only]
module memez_locks::lock_tests;

use sui::{
    test_scenario as ts,
    test_utils::{assert_eq, destroy}
};

use memez_locks::lock;

const ADMIN: address = @0xdead;

public struct Position has key, store {
    id: UID,
    value: u64
}

#[test]
fun test_end_to_end() {
    let mut scenario = ts::begin(ADMIN); 

    let ctx_mut = scenario.ctx();
    
    let mut lock = lock::new(       
        Position {
            id: object::new(ctx_mut),
            value: 100
        },
        10,
        ctx_mut
    );

    assert_eq(lock.unlock_epoch(), 10); 

    let (amount_a, amount_b) = lock.amounts(); 

    assert_eq(amount_a, 0);
    assert_eq(amount_b, 0);

    let position = lock.borrow<Position>(); 

    assert_eq(position.value, 100);

    let position_mut = lock.borrow_mut<Position>(); 

    position_mut.value = 200; 

    let position = lock.borrow<Position>(); 

    assert_eq(position.value, 200);

    lock.add_amounts(10, 10);

    let (amount_a, amount_b) = lock.amounts(); 

    assert_eq(amount_a, 10);
    assert_eq(amount_b, 10);

    lock.add_amounts(12, 12);

    let (amount_a, amount_b) = lock.amounts(); 

    assert_eq(amount_a, 22);
    assert_eq(amount_b, 22);

    lock.add_amounts(100, 100);

    let (amount_a, amount_b) = lock.amounts(); 

    assert_eq(amount_a, 122);
    assert_eq(amount_b, 122);

    lock.add_amounts(100, 100);

    let (amount_a, amount_b) = lock.amounts(); 

    assert_eq(amount_a, 222);
    assert_eq(amount_b, 222); 

    scenario.next_epoch(ADMIN);
    scenario.next_epoch(ADMIN);
    scenario.next_epoch(ADMIN);
    scenario.next_epoch(ADMIN);
    scenario.next_epoch(ADMIN);
    scenario.next_epoch(ADMIN);
    scenario.next_epoch(ADMIN);
    scenario.next_epoch(ADMIN);
    scenario.next_epoch(ADMIN);
    scenario.next_epoch(ADMIN);
    scenario.next_epoch(ADMIN);

    let ctx_mut = scenario.ctx();

    let position = lock.destroy<Position>(ctx_mut);
    
    let Position { id, .. } = position; 

    id.delete();

    scenario.end();
}

#[test]
#[expected_failure(abort_code = lock::EInvalidEpoch)]
fun test_invalid_epoch() {
    let mut scenario = ts::begin(ADMIN); 

    scenario.next_epoch(ADMIN);

    let ctx_mut = scenario.ctx();

    let lock = lock::new(       
        Position {
            id: object::new(ctx_mut),
            value: 100
        },
        1,
        ctx_mut
    );

    destroy(lock);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = lock::EPositionLocked)]
fun test_position_locked() {
    let mut scenario = ts::begin(ADMIN);  

    let ctx_mut = scenario.ctx();

    let lock = lock::new(       
        Position {
            id: object::new(ctx_mut),
            value: 100
        },
        1,
        ctx_mut
    );

    scenario.next_epoch(ADMIN);

    let ctx_mut = scenario.ctx();

    destroy(lock.destroy<Position>(ctx_mut));

    scenario.end();
}