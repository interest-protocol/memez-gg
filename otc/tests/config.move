#[test_only, allow(unused_mut_ref)]
module memez_otc::config_tests;

use memez_acl::acl;
use memez_otc::config::{Self, MemezOTCConfig};
use sui::{test_scenario::{Self as ts, Scenario}, test_utils::{assert_eq, destroy}};

const ADMIN: address = @0x7;

const ONE_PERCENT: u64 = 100;

public struct Dapp {
    scenario: vector<Scenario>,
    config: vector<MemezOTCConfig>,
}

#[test]
fun test_init() {
    let mut dapp = deploy();

    dapp.tx!(|config, _| {
        assert_eq(config.fee().value(), ONE_PERCENT);
        assert_eq(config.treasury(), @treasury);
    });

    dapp.end();
}

#[test]
fun test_admin_functions() {
    let mut dapp = deploy();

    dapp.tx!(|config, _| {
        assert_eq(config.fee().value(), ONE_PERCENT);

        let witness = acl::sign_in_for_testing();

        config.set_fee(&witness, ONE_PERCENT * 3);

        assert_eq(config.fee().value(), ONE_PERCENT * 3);
    });

    dapp.tx!(|config, _| {
        assert_eq(config.treasury(), @treasury);

        let witness = acl::sign_in_for_testing();

        config.set_treasury(&witness, ADMIN);

        assert_eq(config.treasury(), ADMIN);
    });

    dapp.end();
}

macro fun tx($dapp: &mut Dapp, $f: |&mut MemezOTCConfig, &mut Scenario|) {
    let dapp = $dapp;
    let mut config = dapp.config.pop_back();
    let mut scenario = dapp.scenario.pop_back();

    $f(&mut config, &mut scenario);

    dapp.scenario.push_back(scenario);
    dapp.config.push_back(config);
}

fun deploy(): Dapp {
    let mut scenario = ts::begin(ADMIN);

    config::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let config = scenario.take_shared<MemezOTCConfig>();

    Dapp {
        scenario: vector[scenario],
        config: vector[config],
    }
}

fun end(dapp: Dapp) {
    destroy(dapp);
}
