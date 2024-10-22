#[test_only]
module memez_coin_registry::memez_coin_registry_tests;

use sui::{
    test_utils::{assert_eq, destroy},
    coin::{TreasuryCap, CoinMetadata},
    test_scenario::{Self as ts, Scenario},
};

use coin_v2::{
    coin_v2,
    aptos::{Self, APTOS},
};

use memez_coin_registry::{
    eth::{Self, ETH},
    memez_coin_registry::{Self, MemezCoinRegistry}
};

const ADMIN: address = @0x0; 

public struct World {
    scenario: Scenario,
    treasury: vector<TreasuryCap<APTOS>>,
    metadata: CoinMetadata<APTOS>,
    registry: MemezCoinRegistry,
}

#[test]
fun test_end_to_end() {
    let mut world = start();

    let aptos_treasury = world.treasury.pop_back();

    let (treasury_cap_v2, mut cap_witness) = coin_v2::new(
        aptos_treasury, 
        world.scenario.ctx()
    );

    let mint_cap = cap_witness.create_mint_cap(world.scenario.ctx());
    let metadata_cap = cap_witness.create_metadata_cap(world.scenario.ctx());
    let burn_cap = cap_witness.create_burn_cap(world.scenario.ctx());

    let aptos_metadata = &world.metadata;

    assert_eq(world.registry.get<APTOS>().is_none(), true);

    world.registry.add<APTOS>(
        &treasury_cap_v2, 
        aptos_metadata, 
        cap_witness
    );

    assert_eq(world.registry.get<APTOS>().is_some(), true);

    let coin_info = world.registry.get<APTOS>().destroy_some();

    assert_eq(coin_info.metadata(), object::id(aptos_metadata).to_address());
    assert_eq(coin_info.mint_cap(), object::id(&mint_cap).to_address());
    assert_eq(coin_info.burn_cap(), object::id(&burn_cap).to_address());
    assert_eq(coin_info.metadata_cap(), object::id(&metadata_cap).to_address());
    assert_eq(coin_info.treasury_cap_v2(), object::id(&treasury_cap_v2).to_address());

    mint_cap.destroy();
    metadata_cap.destroy();
    burn_cap.destroy();

    destroy(treasury_cap_v2);
    world.end();
}

#[test]
fun test_no_caps() {
    let mut world = start();

    let aptos_treasury = world.treasury.pop_back();

    let (treasury_cap_v2, cap_witness) = coin_v2::new(
        aptos_treasury, 
        world.scenario.ctx()
    );

    let aptos_metadata = &world.metadata;

    world.registry.add<APTOS>(
        &treasury_cap_v2, 
        aptos_metadata, 
        cap_witness
    );

    assert_eq(world.registry.get<APTOS>().is_some(), true);

    let coin_info = world.registry.get<APTOS>().destroy_some();

    assert_eq(coin_info.metadata(), object::id(aptos_metadata).to_address());
    assert_eq(coin_info.mint_cap(), @0x0);
    assert_eq(coin_info.burn_cap(), @0x0);
    assert_eq(coin_info.metadata_cap(), @0x0);
    assert_eq(coin_info.treasury_cap_v2(), object::id(&treasury_cap_v2).to_address());
    
    destroy(treasury_cap_v2);
    world.end();
}

#[test]
#[expected_failure(abort_code = memez_coin_registry::EInvalidCoinType)]
fun test_invalid_coin_type() {
    let mut world = start();

    eth::init_for_testing(world.scenario.ctx());

    world.scenario.next_tx(ADMIN);

    let aptos_treasury = world.treasury.pop_back();

    let eth_treasury = world.scenario.take_from_sender<TreasuryCap<ETH>>();
    let eth_metadata = world.scenario.take_shared<CoinMetadata<ETH>>();

    let (treasury_cap_v2, cap_witness) = coin_v2::new(
        aptos_treasury, 
        world.scenario.ctx()
    );

    let (eth_treasury_cap_v2, _) = coin_v2::new(
        eth_treasury, 
        world.scenario.ctx()
    );

    world.registry.add<ETH>(
        &eth_treasury_cap_v2, 
        &eth_metadata, 
        cap_witness
    );
    
    destroy(treasury_cap_v2);
    destroy(eth_metadata);
    destroy(eth_treasury_cap_v2);
    world.end();
}

#[test]
#[expected_failure(abort_code = memez_coin_registry::EInvalidTreasuryCap)]
fun test_invalid_treasury_cap() {
    let mut world = start();

    eth::init_for_testing(world.scenario.ctx());

    world.scenario.next_tx(ADMIN);

    let aptos_treasury = world.treasury.pop_back();

    let eth_treasury = world.scenario.take_from_sender<TreasuryCap<ETH>>();
    let eth_metadata = world.scenario.take_shared<CoinMetadata<ETH>>();

    let (treasury_cap_v2, _) = coin_v2::new(
        aptos_treasury, 
        world.scenario.ctx()
    );

    let (eth_treasury_cap_v2, eth_cap_witness) = coin_v2::new(
        eth_treasury, 
        world.scenario.ctx()
    );

    world.registry.add<ETH>(
        &treasury_cap_v2, 
        &eth_metadata, 
        eth_cap_witness
    );
    
    destroy(treasury_cap_v2);
    destroy(eth_metadata);
    destroy(eth_treasury_cap_v2);
    world.end();
}

fun start(): World {
    let mut scenario = ts::begin(ADMIN);

    memez_coin_registry::init_for_testing(scenario.ctx());
    aptos::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN); 

    let registry = scenario.take_shared<MemezCoinRegistry>();

    let treasury = scenario.take_from_sender<TreasuryCap<APTOS>>();
    let metadata = scenario.take_shared<CoinMetadata<APTOS>>();
    
    World { 
        scenario, 
        registry,
        treasury: vector[treasury],
        metadata,
    }
}

fun end(world: World) {
    destroy(world);
}