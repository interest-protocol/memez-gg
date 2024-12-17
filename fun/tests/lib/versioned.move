#[test_only]
module memez_fun::versioned_tests;

use memez_fun::memez_versioned;
use sui::test_utils::{destroy, assert_eq};

public struct State has key, store {
    id: UID,
    value: u64,
}

public struct State2 has key, store {
    id: UID,
    value: u64,
}

#[test]
fun test_upgrade() {
    let mut ctx = tx_context::dummy();

    let init_value = State {
        id: object::new(&mut ctx),
        value: 1000,
    };

    let mut wrapper = memez_versioned::create(1, init_value, &mut ctx);

    assert_eq(wrapper.version(), 1);
    assert_eq(wrapper.load_value<State>().value, 1000);

    let (old, cap) = wrapper.remove_value_for_upgrade<State>();

    assert_eq(old.value, 1000);

    destroy(old);

    let new_state = State2 {
        id: object::new(&mut ctx),
        value: 2000,
    };

    wrapper.upgrade(2, new_state, cap);
    assert_eq(wrapper.version(), 2);
    assert_eq(wrapper.load_value<State2>().value, 2000);

    let state2 = wrapper.destroy<State2>();

    assert_eq(state2.value, 2000);

    destroy(state2);
}
