#[test_only, allow(unused_mut_ref)]
module memez_otc::memez_otc_tests;

use memez_otc::{config::{Self, MemezOTCConfig}, memez_otc::{Self, MemezOTC}};
use sui::{
    clock::{Self, Clock},
    coin,
    sui::SUI,
    test_scenario::{Self as ts, Scenario},
    test_utils::{assert_eq, destroy}
};

const ADMIN: address = @0x7;

const OWNER: address = @0xa11ce;

const RECIPIENT: address = @0xdeadbeef;

const SUI_SCALAR: u64 = 1__000_000_000;

const SALE_AMOUNT: u64 = 1_000 * SUI_SCALAR;

const DESIRED_SUI_AMOUNT: u64 = 50 * SUI_SCALAR;

public struct Meme()

public struct OTC {
    normal: vector<MemezOTC<Meme>>
}

public struct Dapp {
    scenario: vector<Scenario>,
    config: vector<MemezOTCConfig>,
    otc: vector<OTC>,
    clock: vector<Clock>,
}

macro fun tx($dapp: &mut Dapp, $f: |&mut OTC, &mut Scenario|) {
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

    scenario.next_tx(OWNER);

    let clock = clock::create_for_testing(scenario.ctx());

    let otc = memez_otc::new(
        &config,
        &clock,
        coin::mint_for_testing<Meme>(SALE_AMOUNT, scenario.ctx()),
        DESIRED_SUI_AMOUNT,
        RECIPIENT,
        option::none(),
        option::none(),
        scenario.ctx(),
    );

    Dapp {
        scenario: vector[scenario],
        config: vector[config],
        otc: vector[OTC {
            normal: vector[otc],
        }],
        clock: vector[clock],
    }
}

public fun end(dapp: Dapp) {
    destroy(dapp);
}
