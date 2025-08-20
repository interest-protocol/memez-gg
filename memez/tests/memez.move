#[test_only]
module memez::memez_tests;

use interest_access_control::access_control::{SuperAdmin, ACL};
use memez::memez::{Self, MEMEZ};
use sui::{test_scenario, test_utils::{destroy, assert_eq}};

const SENDER: address = @0x1;

#[test]
fun test_init() {
    let mut scenario = test_scenario::begin(SENDER);

    memez::init_for_test(scenario.ctx());

    scenario.next_tx(SENDER);

    let acl = scenario.take_shared<ACL<MEMEZ>>();
    let super_admin = scenario.take_from_sender<SuperAdmin<MEMEZ>>();

    destroy(super_admin);
    destroy(acl);
    destroy(scenario);
}
