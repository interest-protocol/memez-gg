#[test_only]
module memez_fun::memez_events_wrapper_tests;

use memez_fun::memez_events_wrapper;
use std::unit_test::assert_eq;
use sui::test_scenario as ts;

public struct TestEvent() has copy, drop;

#[test]
fun test_emit_event() {
    let mut scenario = ts::begin(@0x0);

    memez_events_wrapper::emit_event(TestEvent());

    let effects = scenario.next_tx(@0x0);

    assert_eq!(effects.num_user_events(), 1);

    memez_events_wrapper::emit_event(TestEvent());
    memez_events_wrapper::emit_event(TestEvent());

    let effects = scenario.next_tx(@0x0);

    assert_eq!(effects.num_user_events(), 2);

    scenario.end();
}
