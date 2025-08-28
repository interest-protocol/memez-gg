#[test_only]
module memez_wallet::memez_wallet_tests;

use memez_wallet::memez_wallet::{Self, MemezWalletRegistry, MemezWallet};
use sui::{
    coin::{Self, Coin},
    package::Publisher,
    sui::SUI,
    test_scenario::{Self, Scenario},
    test_utils::{destroy, assert_eq}
};

const SENDER: address = @0x1;

const USER: address = @0x2;

public struct NFT has key, store {
    id: UID,
}

public struct Env {
    registry: MemezWalletRegistry,
    scenario: Scenario,
}

#[test]
fun test_init() {
    let mut scenario = test_scenario::begin(SENDER);

    memez_wallet::init_for_test(scenario.ctx());

    scenario.next_tx(SENDER);

    let publisher = scenario.take_from_sender<Publisher>();
    let registry = scenario.take_shared<MemezWalletRegistry>();

    assert_eq(publisher.from_package<NFT>(), true);

    destroy(registry);
    destroy(publisher);
    destroy(scenario);
}

#[test]
fun test_new() {
    let mut env = new_env();

    assert_eq(env.registry.wallet_address(SENDER).is_none(), true);
    assert_eq(env.registry.wallet_address(USER).is_none(), true);

    let ctx = env.scenario.ctx();

    let wallet = env.registry.new(USER, ctx);

    assert_eq(wallet.owner(), USER);

    let wallet_address = object::id_address(&wallet);

    assert_eq(env.registry.wallet_address(USER).destroy_some(), wallet_address);
    assert_eq(env.registry.wallet_address(SENDER).is_none(), true);

    wallet.share();

    env.scenario.next_tx(SENDER);

    let wallet = env.scenario.take_shared<MemezWallet>();

    assert_eq(object::id_address(&wallet), wallet_address);

    destroy(wallet);
    destroy(env);
}

#[test]
fun test_public_receive() {
    let mut env = new_env();

    let mut wallet = env.registry.new(USER, env.scenario.ctx());

    let nft = NFT { id: object::new(env.scenario.ctx()) };

    let nft_id = object::id(&nft);

    transfer::public_transfer(nft, object::id_address(&wallet));

    env.scenario.next_tx(USER);

    let nft = wallet.receive<NFT>(
        test_scenario::receiving_ticket_by_id<NFT>(nft_id),
        env.scenario.ctx(),
    );

    assert_eq(object::id(&nft), nft_id);

    destroy(nft);
    destroy(wallet);
    destroy(env);
}

#[test]
fun test_merge_coins() {
    let mut env = new_env();

    let mut wallet = env.registry.new(USER, env.scenario.ctx());

    let coin_1 = coin::mint_for_testing<SUI>(100, env.scenario.ctx());
    let coin_2 = coin::mint_for_testing<SUI>(200, env.scenario.ctx());

    let coin_1_id = object::id(&coin_1);
    let coin_2_id = object::id(&coin_2);

    transfer::public_transfer(coin_1, object::id_address(&wallet));
    transfer::public_transfer(coin_2, object::id_address(&wallet));

    // Anyone can merge
    env.scenario.next_tx(SENDER);

    wallet.merge_coins(
        vector[
            test_scenario::receiving_ticket_by_id<Coin<SUI>>(coin_1_id),
            test_scenario::receiving_ticket_by_id<Coin<SUI>>(coin_2_id),
        ],
        env.scenario.ctx(),
    );

    env.scenario.next_tx(SENDER);

    let coin = env.scenario.take_from_address<Coin<SUI>>(object::id_address(&wallet));

    assert_eq(coin.burn_for_testing(), 300);

    destroy(wallet);
    destroy(env);
}

#[test]
fun test_public_receive_coins() {
    let mut env = new_env();

    let mut wallet = env.registry.new(USER, env.scenario.ctx());

    let coin_1 = coin::mint_for_testing<SUI>(100, env.scenario.ctx());
    let coin_2 = coin::mint_for_testing<SUI>(200, env.scenario.ctx());

    let coin_1_id = object::id(&coin_1);
    let coin_2_id = object::id(&coin_2);

    transfer::public_transfer(coin_1, object::id_address(&wallet));
    transfer::public_transfer(coin_2, object::id_address(&wallet));

    // Only the owner
    env.scenario.next_tx(USER);

    let coin = wallet.receive_coins(
        vector[
            test_scenario::receiving_ticket_by_id<Coin<SUI>>(coin_1_id),
            test_scenario::receiving_ticket_by_id<Coin<SUI>>(coin_2_id),
        ],
        env.scenario.ctx(),
    );

    assert_eq(coin.burn_for_testing(), 300);

    destroy(wallet);
    destroy(env);
}

#[test, expected_failure(abort_code = memez_wallet::EInvalidOwner)]
fun test_public_receive_invalid_owner() {
    let mut env = new_env();

    let mut wallet = env.registry.new(USER, env.scenario.ctx());

    let nft = NFT { id: object::new(env.scenario.ctx()) };

    let nft_id = object::id(&nft);

    transfer::public_transfer(nft, object::id_address(&wallet));

    env.scenario.next_tx(SENDER);

    let _nft = wallet.receive<NFT>(
        test_scenario::receiving_ticket_by_id<NFT>(nft_id),
        env.scenario.ctx(),
    );

    abort
}

#[test, expected_failure(abort_code = memez_wallet::EDuplicateWallet)]
fun test_new_duplicate_wallet_error() {
    let mut env = new_env();

    assert_eq(env.registry.wallet_address(SENDER).is_none(), true);

    let ctx = env.scenario.ctx();

    let _wallet = env.registry.new(USER, ctx);
    let _duplicate_wallet = env.registry.new(USER, ctx);

    abort
}

#[test, expected_failure(abort_code = memez_wallet::EInvalidOwner)]
fun test_public_receive_coins_invalid_owner() {
    let mut env = new_env();

    let mut wallet = env.registry.new(USER, env.scenario.ctx());

    let coin_1 = coin::mint_for_testing<SUI>(100, env.scenario.ctx());
    let coin_2 = coin::mint_for_testing<SUI>(200, env.scenario.ctx());

    let coin_1_id = object::id(&coin_1);
    let coin_2_id = object::id(&coin_2);

    transfer::public_transfer(coin_1, object::id_address(&wallet));
    transfer::public_transfer(coin_2, object::id_address(&wallet));

    env.scenario.next_tx(SENDER);

    let _coin = wallet.receive_coins(
        vector[
            test_scenario::receiving_ticket_by_id<Coin<SUI>>(coin_1_id),
            test_scenario::receiving_ticket_by_id<Coin<SUI>>(coin_2_id),
        ],
        env.scenario.ctx(),
    );

    abort
}

fun new_env(): Env {
    let mut scenario = test_scenario::begin(SENDER);

    memez_wallet::init_for_test(scenario.ctx());

    scenario.next_tx(SENDER);

    let registry = scenario.take_shared<MemezWalletRegistry>();

    Env {
        registry,
        scenario,
    }
}
