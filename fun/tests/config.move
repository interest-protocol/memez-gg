#[test_only]
module memez_fun::memez_config_tests;

use memez_acl::acl;
use memez_fun::{
    memez_auction_config::AuctionConfig,
    memez_config::{Self, MemezConfig, DefaultKey, FeesKey, AuctionKey, PumpKey, StableKey},
    memez_errors,
    memez_fees::MemezFees,
    memez_pump_config::PumpConfig,
    memez_stable_config::StableConfig
};
use std::unit_test::assert_eq;
use sui::{test_scenario::{Self as ts, Scenario}, test_utils::destroy};

public struct World {
    scenario: Scenario,
    config: MemezConfig,
}

public struct Quote()

public struct InvalidQuote()

const ADMIN: address = @0x0;

#[test]
fun test_set_fees() {
    let mut world = start();

    assert_eq!(memez_config::exists_for_testing<FeesKey<DefaultKey>>(&world.config), false);

    let witness = acl::sign_in_for_testing();

    world
        .config
        .set_fees<DefaultKey>(
            &witness,
            vector[
                vector[7_000, 3_000, 2],
                vector[5_000, 5_000, 30],
                vector[10_000, 0, 6],
                vector[0, 10_000, 0, 8],
            ],
            vector[vector[@0x0, @0x1], vector[@0x1], vector[@0x2], vector[@0x3]],
            world.scenario.ctx(),
        );

    assert_eq!(memez_config::exists_for_testing<FeesKey<DefaultKey>>(&world.config), true);

    let fees = world.config.fees<DefaultKey>();

    let payloads = fees.payloads();

    assert_eq!(payloads[0].payload_value(), 2);
    assert_eq!(payloads[1].payload_value(), 30);
    assert_eq!(payloads[2].payload_value(), 6);
    assert_eq!(payloads[3].payload_value(), 8);

    assert_eq!(payloads[0].payload_percentages(), vector[7_000, 3_000]);
    assert_eq!(payloads[1].payload_percentages(), vector[5_000, 5_000]);
    assert_eq!(payloads[2].payload_percentages(), vector[10_000, 0]);
    assert_eq!(payloads[3].payload_percentages(), vector[0, 10_000]);

    assert_eq!(payloads[0].payload_recipients(), vector[@0x0, @0x1]);
    assert_eq!(payloads[1].payload_recipients(), vector[@0x1]);
    assert_eq!(payloads[2].payload_recipients(), vector[@0x2]);
    assert_eq!(payloads[3].payload_recipients(), vector[@0x3]);

    world.config.remove<FeesKey<DefaultKey>, MemezFees>(&witness, world.scenario.ctx());

    assert_eq!(memez_config::exists_for_testing<FeesKey<DefaultKey>>(&world.config), false);

    world.end();
}

#[test]
fun test_auction() {
    let mut world = start();

    let witness = acl::sign_in_for_testing();

    let third_minutes_ms = 3 * 60 * 1_000_000;
    let burn_take = 2000;
    let virtual_liquidity = 1000;
    let target_liquidity = 10_000;
    let provision_liquidity = 500;
    let seed_liquidity = 100;

    world
        .config
        .set_auction<Quote, DefaultKey>(
            &witness,
            vector[
                third_minutes_ms,
                burn_take,
                virtual_liquidity,
                target_liquidity,
                provision_liquidity,
                seed_liquidity,
            ],
            world.scenario.ctx(),
        );

    let amounts = world.config.get_auction<Quote, DefaultKey>(1_000);

    assert_eq!(amounts[0], third_minutes_ms);
    assert_eq!(amounts[1], burn_take);
    assert_eq!(amounts[2], virtual_liquidity);
    assert_eq!(amounts[3], target_liquidity);
    assert_eq!(amounts[4], 50);
    assert_eq!(amounts[5], seed_liquidity);

    assert_eq!(memez_config::exists_for_testing<AuctionKey<DefaultKey>>(&world.config), true);

    world.config.remove<AuctionKey<DefaultKey>, AuctionConfig>(&witness, world.scenario.ctx());

    assert_eq!(memez_config::exists_for_testing<AuctionKey<DefaultKey>>(&world.config), false);

    world.end();
}

#[test]
fun test_pump() {
    let mut world = start();

    let witness = acl::sign_in_for_testing();

    let burn_take = 2000;
    let virtual_liquidity = 1000;
    let target_liquidity = 10_000;
    let provision_liquidity = 700;

    world
        .config
        .set_pump<Quote, DefaultKey>(
            &witness,
            vector[burn_take, virtual_liquidity, target_liquidity, provision_liquidity],
            world.scenario.ctx(),
        );

    let amounts = world.config.get_pump<Quote, DefaultKey>(1_000);

    assert_eq!(amounts[0], burn_take);
    assert_eq!(amounts[1], virtual_liquidity);
    assert_eq!(amounts[2], target_liquidity);
    assert_eq!(amounts[3], 70);

    assert_eq!(memez_config::exists_for_testing<PumpKey<DefaultKey>>(&world.config), true);

    world.config.remove<PumpKey<DefaultKey>, PumpConfig>(&witness, world.scenario.ctx());

    assert_eq!(memez_config::exists_for_testing<PumpKey<DefaultKey>>(&world.config), false);

    world.end();
}

#[test]
fun test_stable() {
    let mut world = start();

    let witness = acl::sign_in_for_testing();

    let max_target_sui_liquidity = 10_000;
    let liquidity_provision = 100;
    let meme_sale_amount = 5_000;

    world
        .config
        .set_stable<Quote, DefaultKey>(
            &witness,
            vector[max_target_sui_liquidity, liquidity_provision, meme_sale_amount],
            world.scenario.ctx(),
        );

    let amounts = world.config.get_stable<Quote, DefaultKey>(1_000);

    assert_eq!(amounts[0], max_target_sui_liquidity);
    assert_eq!(amounts[1], 10);
    assert_eq!(amounts[2], 500);

    assert_eq!(memez_config::exists_for_testing<StableKey<DefaultKey>>(&world.config), true);

    world.config.remove<StableKey<DefaultKey>, StableConfig>(&witness, world.scenario.ctx());

    assert_eq!(memez_config::exists_for_testing<StableKey<DefaultKey>>(&world.config), false);

    world.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EInvalidQuoteType,
        location = memez_fun::memez_auction_config,
    ),
]
fun test_auction_invalid_quote_type() {
    let mut world = start();

    let witness = acl::sign_in_for_testing();

    let third_minutes_ms = 3 * 60 * 1_000_000;
    let burn_take = 2000;
    let virtual_liquidity = 1000;
    let target_liquidity = 10_000;
    let provision_liquidity = 500;
    let seed_liquidity = 100;

    world
        .config
        .set_auction<Quote, DefaultKey>(
            &witness,
            vector[
                third_minutes_ms,
                burn_take,
                virtual_liquidity,
                target_liquidity,
                provision_liquidity,
                seed_liquidity,
            ],
            world.scenario.ctx(),
        );

    world.config.get_auction<InvalidQuote, DefaultKey>(1_000);

    world.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EInvalidQuoteType,
        location = memez_fun::memez_pump_config,
    ),
]
fun test_pump_invalid_quote_type() {
    let mut world = start();

    let witness = acl::sign_in_for_testing();

    let burn_take = 2000;
    let virtual_liquidity = 1000;
    let target_liquidity = 10_000;
    let provision_liquidity = 700;

    world
        .config
        .set_pump<Quote, DefaultKey>(
            &witness,
            vector[burn_take, virtual_liquidity, target_liquidity, provision_liquidity],
            world.scenario.ctx(),
        );

    world.config.get_pump<InvalidQuote, DefaultKey>(1_000);

    world.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EInvalidQuoteType,
        location = memez_fun::memez_stable_config,
    ),
]
fun test_stable_invalid_quote_type() {
    let mut world = start();

    let witness = acl::sign_in_for_testing();

    let max_target_sui_liquidity = 10_000;
    let liquidity_provision = 100;
    let meme_sale_amount = 5_000;

    world
        .config
        .set_stable<Quote, DefaultKey>(
            &witness,
            vector[max_target_sui_liquidity, liquidity_provision, meme_sale_amount],
            world.scenario.ctx(),
        );

    world.config.get_stable<InvalidQuote, DefaultKey>(1_000);

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
