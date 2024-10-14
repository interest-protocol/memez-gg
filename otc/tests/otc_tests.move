#[test_only]
module memez_otc::otc_tests;

use sui::{
    sui::SUI,
    clock::{Self, Clock},
    coin::mint_for_testing,
    test_scenario::{Self, Scenario},
    test_utils::{assert_eq, destroy}
};

use memez_otc::{
    fees::{Self, Fees},
    otc::{Self, MemezOTC, MemezOTCAccount}
};

const ADMIN: address = @0x1;

const ALICE: address = @0xa11ce;

const TOTAL_MEME_AMOUNT: u64 = 2__000;

public struct Meme has drop {}

public struct World {
    scenario: Scenario,
    account: MemezOTCAccount,
    clock: Clock,
    fees: Fees,
}

#[test]
fun initiates_correctly() {
    let mut world = start(); 

    let account_address = world.account.addy(); 

    let fees = &world.fees;
    let ctx = world.scenario.ctx();
    let account = &mut world.account;

    account.new(
        fees, 
        mint_for_testing<Meme>(TOTAL_MEME_AMOUNT, ctx), 
        ALICE,
        500, 
        option::some(100),
        option::some(170),
        ctx
    );

    world.scenario.next_tx(ADMIN); 

    let otc = world.scenario.take_shared<MemezOTC<Meme>>();

    assert_eq(otc.balance(), TOTAL_MEME_AMOUNT);
    assert_eq(otc.owner(), account_address);
    assert_eq(otc.recipient(), ALICE);
    assert_eq(otc.deposited_amount(), TOTAL_MEME_AMOUNT);
    assert_eq(otc.price(), 500);
    assert_eq(otc.vesting_duration(), option::some(100));
    assert_eq(otc.deadline(), option::some(170));
    
    destroy(otc);
    world.end();
}

#[test]
fun test_buy() {
    let mut world = start(); 

    let fees = &world.fees;

    world.account.new(
        fees, 
        mint_for_testing<Meme>(TOTAL_MEME_AMOUNT, world.scenario.ctx()), 
        ALICE,
        500, 
        option::none(),
        option::none(),
        world.scenario.ctx()
    );

    world.scenario.next_tx(ADMIN); 

    let mut otc = world.scenario.take_shared<MemezOTC<Meme>>();

    let meme_coin = otc.buy(
        mint_for_testing<SUI>(100, world.scenario.ctx()), 
        world.scenario.ctx()
    );

    let expected_meme_coin_amount = otc.calculate_amount_out(100);

    assert_eq(meme_coin.value(), expected_meme_coin_amount); 
    assert_eq(100, otc.calculate_amount_in(meme_coin.value()));
    
    destroy(meme_coin);

    let meme_coin = otc.buy(
        mint_for_testing<SUI>(233, world.scenario.ctx()), 
        world.scenario.ctx()
    );

    let expected_meme_coin_amount = otc.calculate_amount_out(233);

    assert_eq(meme_coin.value(), expected_meme_coin_amount); 
    // Round up for amount_in is fine
    assert_eq(233 + 1, otc.calculate_amount_in(meme_coin.value()));

    destroy(otc);
    destroy(meme_coin);
    world.end();
}

#[test]
fun test_buy_with_deadline() {
    let mut world = start();  

    let fees = &world.fees;

    world.account.new(
        fees, 
        mint_for_testing<Meme>(TOTAL_MEME_AMOUNT, world.scenario.ctx()), 
        ALICE,
        500, 
        option::none(),
        option::some(100),
        world.scenario.ctx()
    );

    world.scenario.next_tx(ADMIN); 

    world.clock.increment_for_testing(99);

    let mut otc = world.scenario.take_shared<MemezOTC<Meme>>();

    let wallet = otc.buy_with_deadline(
        &world.clock,
        mint_for_testing<SUI>(100, world.scenario.ctx()), 
        world.scenario.ctx()
    );

    destroy(wallet);
    destroy(otc);
    world.end();
}

#[test]
fun test_buy_vested_with_deadline() {
    let mut world = start(); 

    let fees = &world.fees;

    world.account.new(
        fees, 
        mint_for_testing<Meme>(TOTAL_MEME_AMOUNT, world.scenario.ctx()), 
        ALICE,
        500, 
        option::some(100),
        option::some(170),
        world.scenario.ctx()
    );
    
    world.scenario.next_tx(ADMIN); 

    world.clock.increment_for_testing(169);

    let mut otc = world.scenario.take_shared<MemezOTC<Meme>>();

    let wallet = otc.buy_vested_with_deadline(
        &world.clock,
        mint_for_testing<SUI>(100, world.scenario.ctx()), 
        world.scenario.ctx()
    );

    let expected_meme_coin_amount = otc.calculate_amount_out(100);

    assert_eq(expected_meme_coin_amount, wallet.balance()); 
    assert_eq(0, wallet.released()); 
    assert_eq(100, wallet.duration());

    destroy(wallet);
    destroy(otc);
    world.end();
}


#[test]
fun test_buy_vested() {
    let mut world = start(); 

    let fees = &world.fees;

    world.account.new(
        fees, 
        mint_for_testing<Meme>(TOTAL_MEME_AMOUNT, world.scenario.ctx()), 
        ALICE,
        500, 
        option::some(189),
        option::none(),
        world.scenario.ctx()
    );

    world.scenario.next_tx(ADMIN); 

    let mut otc = world.scenario.take_shared<MemezOTC<Meme>>();

    let wallet = otc.buy_vested(
        &world.clock,
        mint_for_testing<SUI>(100, world.scenario.ctx()), 
        world.scenario.ctx()
    );

    let expected_meme_coin_amount = otc.calculate_amount_out(100);

    assert_eq(expected_meme_coin_amount, wallet.balance()); 
    assert_eq(0, wallet.released()); 
    assert_eq(189, wallet.duration());

    destroy(wallet);
    destroy(otc);
    world.end();
}

#[test]
fun test_account_functions() {
    let mut world = start(); 

    let fees = &world.fees;

    world.account.new(
        fees, 
        mint_for_testing<Meme>(TOTAL_MEME_AMOUNT, world.scenario.ctx()), 
        ALICE,
        500, 
        option::some(189),
        option::some(170),
        world.scenario.ctx()
    );

    world.scenario.next_tx(ADMIN); 

    let mut otc = world.scenario.take_shared<MemezOTC<Meme>>();

    assert_eq(otc.deadline(), option::some(170));  

    otc.update_deadline(&world.account, 111);

    assert_eq(otc.deadline(), option::some(111)); 

    let balance = otc.balance();

    let deposit = otc.destroy(&world.account, world.scenario.ctx()); 

    assert_eq(deposit.value(), balance);

    destroy(deposit);
    world.end();
}

#[test]
#[expected_failure(abort_code = otc::EZeroPrice)]
fun test_new_with_zero_price() {
    let mut world = start(); 

    let fees = &world.fees;

    world.account.new(
        fees, 
        mint_for_testing<Meme>(TOTAL_MEME_AMOUNT, world.scenario.ctx()), 
        ALICE,
        0, 
        option::some(189),
        option::some(170),
        world.scenario.ctx()
    );

    world.end();
}

#[test]
fun test_destroy() {
    let mut world = start(); 

    let fees = &world.fees; 

    world.account.new(
        fees, 
        mint_for_testing<Meme>(TOTAL_MEME_AMOUNT, world.scenario.ctx()), 
        ALICE,
        500, 
        option::none(),
        option::some(100),
        world.scenario.ctx()
    ); 

    world.scenario.next_tx(ADMIN);

    let otc = world.scenario.take_shared<MemezOTC<Meme>>();

    world.scenario.next_tx(ALICE);

    let meme_coin = otc.destroy(&world.account, world.scenario.ctx());

    assert_eq(meme_coin.value(), TOTAL_MEME_AMOUNT);
    
    destroy(meme_coin);
    world.end();
}

#[test]
#[expected_failure(abort_code = otc::EZeroCoin)]
fun test_buy_after_deadline() {
    let mut world = start(); 

    let fees = &world.fees;

    world.account.new(
        fees, 
        mint_for_testing<Meme>(0, world.scenario.ctx()), 
        ALICE,
        500, 
        option::some(189),
        option::some(170),
        world.scenario.ctx()
    );

    world.end();
}

#[test]
#[expected_failure(abort_code = otc::EVestedOTC)]
fun test_buy_error_vested_otc() {
    let mut world = start(); 

    let fees = &world.fees;

    world.account.new(
        fees, 
        mint_for_testing<Meme>(TOTAL_MEME_AMOUNT, world.scenario.ctx()), 
        ALICE,
        500, 
        option::some(189),
        option::none(),
        world.scenario.ctx()
    );

    world.scenario.next_tx(ADMIN); 

    let mut otc = world.scenario.take_shared<MemezOTC<Meme>>();

    let meme_coin = otc.buy(
        mint_for_testing<SUI>(100, world.scenario.ctx()), 
        world.scenario.ctx()
    );

    destroy(meme_coin);
    destroy(otc);
    world.end();
}

#[test]
#[expected_failure(abort_code = otc::EHasDeadline)]
fun test_buy_error_had_deadline() {
    let mut world = start(); 

    let fees = &world.fees;

    world.account.new(
        fees, 
        mint_for_testing<Meme>(TOTAL_MEME_AMOUNT, world.scenario.ctx()), 
        ALICE,
        500, 
        option::none(),
        option::some(170),
        world.scenario.ctx()
    );

    world.scenario.next_tx(ADMIN); 

    let mut otc = world.scenario.take_shared<MemezOTC<Meme>>();

    let meme_coin = otc.buy(
        mint_for_testing<SUI>(100, world.scenario.ctx()), 
        world.scenario.ctx()
    );

    destroy(meme_coin);
    destroy(otc);
    world.end();
}

#[test]
#[expected_failure(abort_code = otc::EHasNoDeadline)]
fun test_buy_with_deadline_error_had_deadline() {
    let mut world = start(); 

    let fees = &world.fees;

    world.account.new(
        fees, 
        mint_for_testing<Meme>(TOTAL_MEME_AMOUNT, world.scenario.ctx()), 
        ALICE,
        500, 
        option::none(),
        option::none(),
        world.scenario.ctx()
    );

    world.scenario.next_tx(ADMIN); 

    let mut otc = world.scenario.take_shared<MemezOTC<Meme>>();

    let meme_coin = otc.buy_with_deadline(
        &world.clock,
        mint_for_testing<SUI>(100, world.scenario.ctx()), 
        world.scenario.ctx()
    );

    destroy(meme_coin);
    destroy(otc);
    world.end();
}

#[test]
#[expected_failure(abort_code = otc::ENormalOTC)]
fun test_buy_vested_error_normal_otc() {
    let mut world = start(); 

    let fees = &world.fees;

    world.account.new(
        fees, 
        mint_for_testing<Meme>(TOTAL_MEME_AMOUNT, world.scenario.ctx()), 
        ALICE,
        500, 
        option::none(),
        option::none(),
        world.scenario.ctx()
    );

    world.scenario.next_tx(ADMIN); 

    let mut otc = world.scenario.take_shared<MemezOTC<Meme>>();

    let meme_coin = otc.buy_vested(
        &world.clock,
        mint_for_testing<SUI>(100, world.scenario.ctx()), 
        world.scenario.ctx()
    );

    destroy(meme_coin);
    destroy(otc);
    world.end();
}

#[test]
#[expected_failure(abort_code = otc::EHasDeadline)]
fun test_buy_vested_error_has_deadline() {
    let mut world = start(); 

    let fees = &world.fees;

    world.account.new(
        fees, 
        mint_for_testing<Meme>(TOTAL_MEME_AMOUNT, world.scenario.ctx()), 
        ALICE,
        500, 
        option::some(100),
        option::some(99),
        world.scenario.ctx()
    );

    world.scenario.next_tx(ADMIN); 

    let mut otc = world.scenario.take_shared<MemezOTC<Meme>>();

    let meme_coin = otc.buy_vested(
        &world.clock,
        mint_for_testing<SUI>(100, world.scenario.ctx()), 
        world.scenario.ctx()
    );

    destroy(meme_coin);
    destroy(otc);
    world.end();
}

#[test]
#[expected_failure(abort_code = otc::EHasNoDeadline)]
fun test_buy_vested_with_deadline_error_has_no_deadline() {
    let mut world = start(); 

    let fees = &world.fees;

    world.account.new(
        fees, 
        mint_for_testing<Meme>(TOTAL_MEME_AMOUNT, world.scenario.ctx()), 
        ALICE,
        500, 
        option::none(),
        option::none(),
        world.scenario.ctx()
    );

    world.scenario.next_tx(ADMIN); 

    let mut otc = world.scenario.take_shared<MemezOTC<Meme>>();

    let meme_coin = otc.buy_vested_with_deadline(
        &world.clock,
        mint_for_testing<SUI>(100, world.scenario.ctx()), 
        world.scenario.ctx()
    );

    destroy(meme_coin);
    destroy(otc);
    world.end();
}

#[test]
#[expected_failure(abort_code = otc::EDeadlinePassed)]
fun test_buy_vested_with_deadline_error_deadline_passed() {
    let mut world = start(); 

    let fees = &world.fees;

    world.account.new(
        fees, 
        mint_for_testing<Meme>(TOTAL_MEME_AMOUNT, world.scenario.ctx()), 
        ALICE,
        500, 
        option::some(120),
        option::some(10),
        world.scenario.ctx()
    );

    world.scenario.next_tx(ADMIN); 

    world.clock.increment_for_testing(11);

    let mut otc = world.scenario.take_shared<MemezOTC<Meme>>();

    let meme_coin = otc.buy_vested_with_deadline(
        &world.clock,
        mint_for_testing<SUI>(100, world.scenario.ctx()), 
        world.scenario.ctx()
    );

    destroy(meme_coin);
    destroy(otc);
    world.end();
}

#[test]
#[expected_failure(abort_code = otc::EInvalidBuyAmount)]
fun test_buy_error_invalid_buy_amount() {
    let mut world = start(); 

    let fees = &world.fees;

    world.account.new(
        fees, 
        mint_for_testing<Meme>(TOTAL_MEME_AMOUNT, world.scenario.ctx()), 
        ALICE,
        500, 
        option::none(),
        option::none(),
        world.scenario.ctx()
    );

    world.scenario.next_tx(ALICE);  

    let mut otc = world.scenario.take_shared<MemezOTC<Meme>>();

    let meme_coin = otc.buy(
        mint_for_testing<SUI>(0, world.scenario.ctx()), 
        world.scenario.ctx()
    );

    destroy(meme_coin);
    destroy(otc);
    world.end();
}

#[test]
#[expected_failure(abort_code = otc::ENotEnoughBalance)]
fun test_buy_error_not_enough_balance() {
    let mut world = start(); 

    let fees = &world.fees;

    world.account.new(
        fees, 
        mint_for_testing<Meme>(TOTAL_MEME_AMOUNT, world.scenario.ctx()), 
        ALICE,
        500, 
        option::none(),
        option::none(),
        world.scenario.ctx()
    );

    world.scenario.next_tx(ALICE);  

    let mut otc = world.scenario.take_shared<MemezOTC<Meme>>();

    let meme_coin = otc.buy(
        mint_for_testing<SUI>(500 + 1, world.scenario.ctx()), 
        world.scenario.ctx()
    );

    destroy(meme_coin);
    destroy(otc);
    world.end();
}

#[test]
#[expected_failure(abort_code = otc::EWrongOwner)]
fun test_update_deadline_error_wrong_owner() {
    let mut world = start(); 

    let fees = &world.fees; 

    world.account.new(
        fees, 
        mint_for_testing<Meme>(TOTAL_MEME_AMOUNT, world.scenario.ctx()), 
        ALICE,
        500, 
        option::none(),
        option::some(100),
        world.scenario.ctx()
    ); 

    world.scenario.next_tx(ADMIN);

    let otc = world.scenario.take_shared<MemezOTC<Meme>>();

    world.scenario.next_tx(ALICE);

    let wrong_account = otc::new_account(world.scenario.ctx());

    let meme_coin = otc.destroy(&wrong_account, world.scenario.ctx());

    wrong_account.destroy_account();
    
    destroy(meme_coin);
    world.end();
}

#[test]
#[expected_failure(abort_code = otc::EWrongOwner)]
fun test_destroy_error_wrong_owner() {
    let mut world = start(); 

    let fees = &world.fees; 

    world.account.new(
        fees, 
        mint_for_testing<Meme>(TOTAL_MEME_AMOUNT, world.scenario.ctx()), 
        ALICE,
        500, 
        option::none(),
        option::some(100),
        world.scenario.ctx()
    ); 

    world.scenario.next_tx(ADMIN);

    let mut otc = world.scenario.take_shared<MemezOTC<Meme>>();

    world.scenario.next_tx(ALICE);

    let wrong_account = otc::new_account(world.scenario.ctx());

    otc.update_deadline(&wrong_account, 100);

    wrong_account.destroy_account();
    
    destroy(otc);
    world.end();
}
    
fun start(): World {
    let mut scenario = test_scenario::begin(ADMIN);

    fees::init_for_testing(scenario.ctx()); 

    scenario.next_tx(ADMIN);
    
    let fees = scenario.take_shared<Fees>();

    let account = otc::new_account(scenario.ctx());

    let clock = clock::create_for_testing(scenario.ctx());

    World {
        scenario,
        account,
        clock,
        fees
    }
    
} 

fun end(world: World) {
    destroy(world);
}
