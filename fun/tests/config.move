#[test_only]
module memez_fun::memez_config_tests;

use interest_access_control::access_control;
use interest_bps::bps::BPS;
use memez::memez::MEMEZ;
use memez_fun::{
    memez_config::{Self, MemezConfig, FeesKey, MemeReferrerFeeKey, QuoteReferrerFeeKey},
    memez_fees::MemezFees
};
use std::unit_test::assert_eq;
use sui::{test_scenario::{Self as ts, Scenario}, test_utils::destroy};

public struct World {
    scenario: Scenario,
    config: MemezConfig,
}

public struct Memez()

public struct Quote()

public struct Quote2()

public struct DefaultKey()

const ADMIN: address = @0x0;

#[test]
fun test_set_fees() {
    let mut world = start();

    assert_eq!(memez_config::exists_for_testing<FeesKey<DefaultKey>>(&world.config), false);

    let witness = access_control::sign_in_for_testing<MEMEZ>(0);

    world
        .config
        .set_fees<DefaultKey>(
            &witness,
            vector[
                vector[7_000, 3_000, 2],
                vector[5_000, 5_000, 40],
                vector[4_000, 6_000, 30],
                vector[10_000, 0, 6],
                vector[0, 10_000, 8],
                vector[100, 101],
            ],
            vector[vector[@0x0, @0x1], vector[@0x1], vector[@0x2], vector[@0x3]],
            world.scenario.ctx(),
        );

    assert_eq!(memez_config::exists_for_testing<FeesKey<DefaultKey>>(&world.config), true);

    let fees = world.config.fees<DefaultKey>();

    let payloads = fees.payloads();

    assert_eq!(payloads[0].payload_value(), 2);
    assert_eq!(payloads[1].payload_value(), 40);
    assert_eq!(payloads[2].payload_value(), 30);
    assert_eq!(payloads[3].payload_value(), 6);
    assert_eq!(payloads[4].payload_value(), 8);

    assert_eq!(payloads[0].payload_percentages(), vector[7_000, 3_000]);
    assert_eq!(payloads[1].payload_percentages(), vector[5_000, 5_000]);
    assert_eq!(payloads[2].payload_percentages(), vector[4_000, 6_000]);
    assert_eq!(payloads[3].payload_percentages(), vector[10_000, 0]);
    assert_eq!(payloads[4].payload_percentages(), vector[0, 10_000]);

    assert_eq!(payloads[0].payload_recipients(), vector[@0x0, @0x1]);
    assert_eq!(payloads[1].payload_recipients(), vector[@0x1]);
    assert_eq!(payloads[2].payload_recipients(), vector[@0x1]);
    assert_eq!(payloads[3].payload_recipients(), vector[@0x2]);
    assert_eq!(payloads[4].payload_recipients(), vector[@0x3]);

    world.config.remove<FeesKey<DefaultKey>, MemezFees>(&witness, world.scenario.ctx());

    assert_eq!(memez_config::exists_for_testing<FeesKey<DefaultKey>>(&world.config), false);

    world.end();
}

#[test]
fun test_assert_quote_coin() {
    let mut world = start();

    let witness = access_control::sign_in_for_testing<MEMEZ>(0);

    world.config.add_quote_coin<DefaultKey, Quote>(&witness, world.scenario.ctx());

    world.config.assert_quote_coin<DefaultKey, Quote>();

    world.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_fun::memez_errors::EQuoteCoinNotSupported,
        location = memez_fun::memez_config,
    ),
]
fun test_coin_not_supported() {
    let mut world = start();

    let witness = access_control::sign_in_for_testing<MEMEZ>(0);

    world.config.add_quote_coin<DefaultKey, Quote>(&witness, world.scenario.ctx());

    world.config.assert_quote_coin<DefaultKey, Quote2>();

    world.end();
}

#[test]
fun test_set_meme_referrer_fee() {
    let mut world = start();

    let witness = access_control::sign_in_for_testing<MEMEZ>(0);

    assert_eq!(
        memez_config::exists_for_testing<MemeReferrerFeeKey<DefaultKey>>(&world.config),
        false,
    );

    assert_eq!(world.config.meme_referrer_fee<DefaultKey>().value(), 0);

    world.config.set_meme_referrer_fee<DefaultKey>(&witness, 1_000, world.scenario.ctx());

    assert_eq!(
        memez_config::exists_for_testing<MemeReferrerFeeKey<DefaultKey>>(&world.config),
        true,
    );

    let meme_referrer_fee = world.config.meme_referrer_fee<DefaultKey>();

    assert_eq!(meme_referrer_fee.value(), 1_000);

    world.config.remove<MemeReferrerFeeKey<DefaultKey>, BPS>(&witness, world.scenario.ctx());

    assert_eq!(
        memez_config::exists_for_testing<MemeReferrerFeeKey<DefaultKey>>(&world.config),
        false,
    );

    world.end();
}

#[test]
fun test_set_quote_referrer_fee() {
    let mut world = start();

    let witness = access_control::sign_in_for_testing<MEMEZ>(0);

    assert_eq!(
        memez_config::exists_for_testing<QuoteReferrerFeeKey<DefaultKey>>(&world.config),
        false,
    );

    assert_eq!(world.config.quote_referrer_fee<DefaultKey>().value(), 0);

    world.config.set_quote_referrer_fee<DefaultKey>(&witness, 1_000, world.scenario.ctx());

    assert_eq!(
        memez_config::exists_for_testing<QuoteReferrerFeeKey<DefaultKey>>(&world.config),
        true,
    );

    let quote_referrer_fee = world.config.quote_referrer_fee<DefaultKey>();

    assert_eq!(quote_referrer_fee.value(), 1_000);

    world.config.remove<QuoteReferrerFeeKey<DefaultKey>, BPS>(&witness, world.scenario.ctx());

    assert_eq!(
        memez_config::exists_for_testing<QuoteReferrerFeeKey<DefaultKey>>(&world.config),
        false,
    );

    world.end();
}

fun start(): World {
    let mut scenario = ts::begin(ADMIN);

    memez_config::init_for_testing(scenario.ctx());

    scenario.next_epoch(ADMIN);

    let config = scenario.take_shared<MemezConfig>();

    World {
        scenario,
        config,
    }
}

fun end(world: World) {
    destroy(world);
}
