#[test_only]
module ipx_coin_standard::ipx_coin_standard_tests;

use ipx_coin_standard::{aptos::{Self, APTOS}, ipx_coin_standard};
use std::type_name;
use sui::{
    coin::{Self, TreasuryCap, CoinMetadata},
    test_scenario as ts,
    test_utils::{assert_eq, destroy}
};

const ADMIN: address = @0xdead;

public struct ETH has drop ()

#[test]
fun test_end_to_end() {
    let mut scenario = ts::begin(ADMIN);

    aptos::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let cap = scenario.take_from_sender<TreasuryCap<APTOS>>();
    let mut metadata = scenario.take_shared<CoinMetadata<APTOS>>();
    let name = type_name::get<APTOS>();

    assert_eq(metadata.get_decimals(), 9);
    assert_eq(metadata.get_symbol(), b"APT".to_ascii_string());
    assert_eq(metadata.get_name(), b"Aptos".to_string());
    assert_eq(metadata.get_description(), b"The second best move chain".to_string());
    assert_eq(metadata.get_icon_url(), option::none());
    assert_eq(cap.total_supply(), 0);

    let (mut treasury_cap, mut witness) = ipx_coin_standard::new(cap, scenario.ctx());

    assert_eq(witness.mint_cap_address().is_none(), true);
    assert_eq(witness.burn_cap_address().is_none(), true);
    assert_eq(witness.metadata_cap_address().is_none(), true);

    let mint_cap = witness.create_mint_cap(scenario.ctx());
    let burn_cap = witness.create_burn_cap(scenario.ctx());
    let metadata_cap = witness.create_metadata_cap(scenario.ctx());

    assert_eq(witness.mint_cap_address().destroy_some(), object::id(&mint_cap).to_address());
    assert_eq(witness.burn_cap_address().destroy_some(), object::id(&burn_cap).to_address());
    assert_eq(
        witness.metadata_cap_address().destroy_some(),
        object::id(&metadata_cap).to_address(),
    );

    assert_eq(treasury_cap.name(), name);
    assert_eq(mint_cap.name(), name);
    assert_eq(burn_cap.name(), name);
    assert_eq(metadata_cap.name(), name);
    assert_eq(witness.name(), name);
    assert_eq(witness.ipx_treasury(), object::id(&treasury_cap).to_address());

    let aptos_coin = mint_cap.mint<APTOS>(&mut treasury_cap, 100, scenario.ctx());

    let effects = scenario.next_tx(ADMIN);

    assert_eq(effects.num_user_events(), 1);

    assert_eq(treasury_cap.total_supply<APTOS>(), 100);
    assert_eq(aptos_coin.value(), 100);

    burn_cap.burn<APTOS>(&mut treasury_cap, aptos_coin);

    let effects = scenario.next_tx(ADMIN);

    assert_eq(effects.num_user_events(), 1);

    assert_eq(treasury_cap.total_supply<APTOS>(), 0);

    let treasury_address = object::id(&treasury_cap).to_address();

    assert_eq(treasury_cap.can_burn(), false);
    assert_eq(treasury_address, mint_cap.ipx_treasury());
    assert_eq(treasury_address, burn_cap.ipx_treasury());
    assert_eq(treasury_address, metadata_cap.ipx_treasury());

    treasury_cap.update_name<APTOS>(&mut metadata, &metadata_cap, b"Aptos V2".to_string());
    treasury_cap.update_symbol<APTOS>(&mut metadata, &metadata_cap, b"APT2".to_ascii_string());
    treasury_cap.update_description<APTOS>(
        &mut metadata,
        &metadata_cap,
        b"Aptos V2 is the best".to_string(),
    );
    treasury_cap.update_icon_url<APTOS>(
        &mut metadata,
        &metadata_cap,
        b"https://aptos.dev/logo.png".to_ascii_string(),
    );

    assert_eq(metadata.get_name(), b"Aptos V2".to_string());
    assert_eq(metadata.get_symbol(), b"APT2".to_ascii_string());
    assert_eq(metadata.get_description(), b"Aptos V2 is the best".to_string());
    assert_eq(
        metadata.get_icon_url().borrow().inner_url(),
        b"https://aptos.dev/logo.png".to_ascii_string(),
    );

    let mint_cap_address = witness.mint_cap_address().destroy_some();
    let burn_cap_address = witness.burn_cap_address().destroy_some();
    let metadata_cap_address = witness.metadata_cap_address().destroy_some();

    assert_eq(mint_cap_address, object::id(&mint_cap).to_address());
    assert_eq(burn_cap_address, object::id(&burn_cap).to_address());
    assert_eq(metadata_cap_address, object::id(&metadata_cap).to_address());

    treasury_cap.destroy_witness<APTOS>(witness);

    let effects = scenario.next_tx(ADMIN);

    assert_eq(effects.num_user_events(), 5);

    assert_eq(treasury_cap.maximum_supply().is_none(), true);

    mint_cap.destroy();
    burn_cap.destroy();
    metadata_cap.destroy();

    destroy(treasury_cap);
    destroy(metadata);
    destroy(scenario);
}

#[test]
fun test_maximum_supply() {
    let mut scenario = ts::begin(ADMIN);

    aptos::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let mut cap = scenario.take_from_sender<TreasuryCap<APTOS>>();
    let aptos_coin = cap.mint<APTOS>(100, scenario.ctx());

    let (mut treasury_cap, mut witness) = ipx_coin_standard::new(cap, scenario.ctx());

    witness.allow_public_burn(&mut treasury_cap);

    witness.set_maximum_supply(100);

    let mint_cap = witness.create_mint_cap(scenario.ctx());

    treasury_cap.destroy_witness<APTOS>(witness);

    treasury_cap.burn(aptos_coin);

    let aptos_coin = mint_cap.mint<APTOS>(&mut treasury_cap, 100, scenario.ctx());

    assert_eq(treasury_cap.maximum_supply().destroy_some(), 100);

    treasury_cap.burn(aptos_coin);

    mint_cap.mint<APTOS>(&mut treasury_cap, 50, scenario.ctx()).burn_for_testing();

    assert_eq(treasury_cap.maximum_supply().destroy_some(), 100);
    assert_eq(treasury_cap.total_supply<APTOS>(), 50);

    destroy(mint_cap);
    destroy(treasury_cap);
    destroy(scenario);
}

#[test]
fun test_treasury_burn() {
    let mut scenario = ts::begin(ADMIN);

    aptos::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let mut cap = scenario.take_from_sender<TreasuryCap<APTOS>>();
    let aptos_coin = cap.mint<APTOS>(100, scenario.ctx());

    let (mut treasury_cap, mut witness) = ipx_coin_standard::new(cap, scenario.ctx());

    witness.allow_public_burn(&mut treasury_cap);

    treasury_cap.burn(aptos_coin);

    treasury_cap.destroy_witness<APTOS>(witness);
    destroy(treasury_cap);
    destroy(scenario);
}

#[test]
#[expected_failure(abort_code = ipx_coin_standard::EMaximumSupplyExceeded)]
fun test_maximum_supply_exceeded() {
    let mut scenario = ts::begin(ADMIN);

    aptos::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let mut cap = scenario.take_from_sender<TreasuryCap<APTOS>>();
    let aptos_coin = cap.mint<APTOS>(100, scenario.ctx());

    let (mut treasury_cap, mut witness) = ipx_coin_standard::new(cap, scenario.ctx());

    witness.allow_public_burn(&mut treasury_cap);

    witness.set_maximum_supply(99);

    treasury_cap.destroy_witness<APTOS>(witness);

    treasury_cap.burn(aptos_coin);

    destroy(treasury_cap);
    destroy(scenario);
}

#[test]
#[expected_failure(abort_code = ipx_coin_standard::EMaximumSupplyExceeded)]
fun test_maximum_supply_exceeded_after_mint() {
    let mut scenario = ts::begin(ADMIN);

    aptos::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let mut cap = scenario.take_from_sender<TreasuryCap<APTOS>>();
    cap.mint<APTOS>(100, scenario.ctx()).burn_for_testing();

    let (mut treasury_cap, mut witness) = ipx_coin_standard::new(cap, scenario.ctx());

    witness.allow_public_burn(&mut treasury_cap);

    witness.set_maximum_supply(101);

    let mint_cap = witness.create_mint_cap(scenario.ctx());

    treasury_cap.destroy_witness<APTOS>(witness);

    mint_cap.mint<APTOS>(&mut treasury_cap, 2, scenario.ctx()).burn_for_testing();

    destroy(mint_cap);
    destroy(treasury_cap);
    destroy(scenario);
}

#[test]
#[expected_failure(abort_code = ipx_coin_standard::ETreasuryCannotBurn)]
fun test_treasury_cannot_burn() {
    let mut scenario = ts::begin(ADMIN);

    aptos::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let mut cap = scenario.take_from_sender<TreasuryCap<APTOS>>();
    let aptos_coin = cap.mint<APTOS>(100, scenario.ctx());

    let (mut treasury_cap, cap_witness) = ipx_coin_standard::new(cap, scenario.ctx());

    treasury_cap.burn(aptos_coin);

    destroy(cap_witness);
    destroy(treasury_cap);
    destroy(scenario);
}

#[test]
#[expected_failure(abort_code = ipx_coin_standard::ECapAlreadyCreated)]
fun test_burn_cap_already_created_for_treasury() {
    let mut scenario = ts::begin(ADMIN);

    let eth_treasury_cap = coin::create_treasury_cap_for_testing<ETH>(scenario.ctx());

    let (mut treasury_cap_v2, mut witness) = ipx_coin_standard::new(
        eth_treasury_cap,
        scenario.ctx(),
    );

    let burn_cap = witness.create_burn_cap(scenario.ctx());

    witness.allow_public_burn(&mut treasury_cap_v2);

    destroy(witness);
    burn_cap.destroy();
    destroy(scenario);
    destroy(treasury_cap_v2);
}

#[test]
#[expected_failure(abort_code = ipx_coin_standard::EInvalidCap)]
fun test_invalid_metadata_cap() {
    let mut scenario = ts::begin(ADMIN);

    aptos::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let aptos_treasury_cap = scenario.take_from_sender<TreasuryCap<APTOS>>();
    let mut aptos_metadata = scenario.take_shared<CoinMetadata<APTOS>>();

    let eth_treasury_cap = coin::create_treasury_cap_for_testing<ETH>(scenario.ctx());

    let (aptos_treasury_cap_v2, cap_witness) = ipx_coin_standard::new(
        aptos_treasury_cap,
        scenario.ctx(),
    );

    let (eth_treasury_cap_v2, mut eth_cap_witness) = ipx_coin_standard::new(
        eth_treasury_cap,
        scenario.ctx(),
    );

    let eth_metadata_cap = eth_cap_witness.create_metadata_cap(scenario.ctx());

    aptos_treasury_cap_v2.update_name<APTOS>(
        &mut aptos_metadata,
        &eth_metadata_cap,
        b"Aptos V2".to_string(),
    );

    destroy(eth_cap_witness);
    destroy(eth_metadata_cap);

    destroy(scenario);
    destroy(cap_witness);
    destroy(aptos_metadata);
    destroy(aptos_treasury_cap_v2);
    destroy(eth_treasury_cap_v2);
}

#[test]
#[expected_failure(abort_code = ipx_coin_standard::EInvalidCap)]
fun test_invalid_mint_cap() {
    let mut scenario = ts::begin(ADMIN);

    aptos::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let aptos_treasury_cap = scenario.take_from_sender<TreasuryCap<APTOS>>();

    let eth_treasury_cap = coin::create_treasury_cap_for_testing<ETH>(scenario.ctx());

    let (mut aptos_treasury_cap_v2, _cap_witness) = ipx_coin_standard::new(
        aptos_treasury_cap,
        scenario.ctx(),
    );

    let (_eth_treasury_cap_v2, mut eth_cap_witness) = ipx_coin_standard::new(
        eth_treasury_cap,
        scenario.ctx(),
    );

    let eth_mint_cap = eth_cap_witness.create_mint_cap(scenario.ctx());

    eth_mint_cap.mint<APTOS>(&mut aptos_treasury_cap_v2, 100, scenario.ctx()).burn_for_testing();

    abort
}

#[test]
#[expected_failure(abort_code = ipx_coin_standard::EInvalidCap)]
fun test_invalid_burn_cap() {
    let mut scenario = ts::begin(ADMIN);

    aptos::init_for_testing(scenario.ctx());

    scenario.next_tx(ADMIN);

    let mut cap = scenario.take_from_sender<TreasuryCap<APTOS>>();

    let eth_cap = coin::create_treasury_cap_for_testing<ETH>(scenario.ctx());

    let aptos_coin = cap.mint<APTOS>(100, scenario.ctx());

    let (mut aptos_treasury_cap_v2, _cap_witness) = ipx_coin_standard::new(cap, scenario.ctx());

    let (_eth_treasury_cap_v2, mut eth_cap_witness) = ipx_coin_standard::new(
        eth_cap,
        scenario.ctx(),
    );

    let eth_burn_cap = eth_cap_witness.create_burn_cap(scenario.ctx());

    eth_burn_cap.burn<APTOS>(&mut aptos_treasury_cap_v2, aptos_coin);

    abort
}

#[test]
#[expected_failure(abort_code = ipx_coin_standard::ECapAlreadyCreated)]
fun test_mint_cap_already_created() {
    let mut scenario = ts::begin(ADMIN);

    let eth_treasury_cap = coin::create_treasury_cap_for_testing<ETH>(scenario.ctx());

    let (_treasury_cap_v2, mut witness) = ipx_coin_standard::new(eth_treasury_cap, scenario.ctx());

    let _mint_cap = witness.create_mint_cap(scenario.ctx());
    let _mint_cap_2 = witness.create_mint_cap(scenario.ctx());

    abort
}

#[test]
#[expected_failure(abort_code = ipx_coin_standard::ECapAlreadyCreated)]
fun test_burn_cap_already_created() {
    let mut scenario = ts::begin(ADMIN);

    let eth_treasury_cap = coin::create_treasury_cap_for_testing<ETH>(scenario.ctx());

    let (_treasury_cap_v2, mut witness) = ipx_coin_standard::new(eth_treasury_cap, scenario.ctx());

    let _burn_cap = witness.create_burn_cap(scenario.ctx());
    let _burn_cap_2 = witness.create_burn_cap(scenario.ctx());

    abort
}

#[test]
#[expected_failure(abort_code = ipx_coin_standard::ECapAlreadyCreated)]
fun test_metadata_cap_already_created() {
    let mut scenario = ts::begin(ADMIN);

    let eth_treasury_cap = coin::create_treasury_cap_for_testing<ETH>(scenario.ctx());

    let (_treasury_cap_v2, mut witness) = ipx_coin_standard::new(eth_treasury_cap, scenario.ctx());

    let _metadata_cap = witness.create_metadata_cap(scenario.ctx());
    let _metadata_cap_2 = witness.create_metadata_cap(scenario.ctx());

    abort
}

#[test]
#[expected_failure(abort_code = ipx_coin_standard::EInvalidTreasury)]
fun test_destroy_cap_witness_invalid_treasury() {
    let mut scenario = ts::begin(ADMIN);

    let eth_treasury_cap = coin::create_treasury_cap_for_testing<ETH>(scenario.ctx());
    let aptos_treasury_cap = coin::create_treasury_cap_for_testing<APTOS>(scenario.ctx());

    let (_treasury_cap_v2, witness) = ipx_coin_standard::new(eth_treasury_cap, scenario.ctx());

    let (mut aptos_treasury_cap, _cap_witness) = ipx_coin_standard::new(
        aptos_treasury_cap,
        scenario.ctx(),
    );

    aptos_treasury_cap.destroy_witness<APTOS>(witness);

    abort
}
