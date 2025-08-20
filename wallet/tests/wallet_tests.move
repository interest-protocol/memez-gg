#[test_only]
module memez_wallet::memez_wallet_tests;

use memez_wallet::memez_wallet::{Self, MemezWalletRegistry};
use sui::{package::Publisher, test_scenario, test_utils::{destroy, assert_eq}};

const SENDER: address = @0x1;

public struct Dummy()

#[test]
fun test_init() {
    let mut scenario = test_scenario::begin(SENDER);

    memez_wallet::init_for_test(scenario.ctx());

    scenario.next_tx(SENDER);

    let publisher = scenario.take_from_sender<Publisher>();
    let registry = scenario.take_shared<MemezWalletRegistry>();

    assert_eq(publisher.from_package<Dummy>(), true);

    destroy(registry);
    destroy(publisher);
    destroy(scenario);
}
