#[test_only, allow(unused_mut_ref, dead_code)]
module memez_otc::memez_otc_tests;

use memez_otc::{config::{Self, MemezOTCConfig}, errors, memez_otc::{Self, MemezOTC}};
use sui::{
    clock::{Self, Clock},
    coin::{Self, Coin},
    sui::SUI,
    test_scenario::{Self as ts, Scenario},
    test_utils::{assert_eq, destroy}
};

const ADMIN: address = @0x7;

const OWNER: address = @0xa11ce;

const RECIPIENT: address = @0xdeadbeef;

const SUI_SCALAR: u64 = 1__000_000_000;

const SALE_AMOUNT: u64 = 1_000 * SUI_SCALAR / 10;

const DESIRED_SUI_AMOUNT: u64 = 50 * SUI_SCALAR;

const DEADLINE: u64 = 1_000;

const VESTING_PERIOD: u64 = 2_000;

public struct Meme()

public struct OTC {
    normal: MemezOTC<Meme>,
    deadline: MemezOTC<Meme>,
    vesting: MemezOTC<Meme>,
    deadline_vesting: MemezOTC<Meme>,
}

public struct Dapp {
    scenario: vector<Scenario>,
    config: vector<MemezOTCConfig>,
    otc: vector<OTC>,
    clock: vector<Clock>,
}

#[test]
fun test_normal_otc_end_to_end() {
    let mut dapp = deploy();

    dapp.tx!(|config, _, otc, _| {
        assert_eq(otc.normal.balance(), SALE_AMOUNT);
        assert_eq(otc.normal.owner(), OWNER);
        assert_eq(otc.normal.recipient(), RECIPIENT);
        assert_eq(otc.normal.fee().value(), config.fee().value());
        assert_eq(otc.normal.desired_sui_amount(), DESIRED_SUI_AMOUNT);
        assert_eq(otc.normal.vesting_duration(), option::none());
        assert_eq(otc.normal.deadline(), option::none());
        assert_eq(otc.normal.treasury(), config.treasury());
    });

    dapp.tx!(|_, _, otc, scenario| {
        scenario.next_tx(OWNER);

        let buy_amount = DESIRED_SUI_AMOUNT / 3;

        let (amount_out, fee) = otc.normal.get_amount_out(buy_amount);
        let (amount_in, fee_in) = otc.normal.get_amount_in(amount_out);

        assert_eq(fee, fee_in);
        assert_eq(buy_amount, amount_in + fee_in);
        
        let (excess_sui, meme_coin) = otc.normal.buy(
            coin::mint_for_testing<SUI>(buy_amount, scenario.ctx()),
            scenario.ctx(),
        );

        assert_eq(meme_coin.burn_for_testing(), amount_out);
        assert_eq(excess_sui.burn_for_testing(), 0);

        scenario.next_tx(RECIPIENT); 

        let recipient_sui_coin = scenario.take_from_sender<Coin<SUI>>();

        assert_eq(recipient_sui_coin.burn_for_testing(), buy_amount - fee);

        let treasury_sui_coin = scenario.take_from_address<Coin<SUI>>(@treasury); 

        assert_eq(treasury_sui_coin.burn_for_testing(), fee);

        assert_eq(otc.normal.balance(), SALE_AMOUNT - amount_out);
    });

    dapp.tx!(|_, _, otc, scenario| {
        scenario.next_tx(OWNER);

        let available_amount = otc.normal.balance();

        let excess_sui_value = 13 * SUI_SCALAR;

        let (amount_in, fee_in) = otc.normal.get_amount_in(available_amount);

        let (excess_sui, meme_coin) = otc.normal.buy(
            coin::mint_for_testing<SUI>(amount_in + fee_in + excess_sui_value, scenario.ctx()),
            scenario.ctx(),
        );

        assert_eq(meme_coin.burn_for_testing(), available_amount);
        assert_eq(excess_sui.burn_for_testing(), excess_sui_value);

        assert_eq(otc.normal.balance(), 0);
    });

    dapp.end();
}

#[test, expected_failure(abort_code = errors::EVestedOTC, location = memez_otc)]
fun test_buy_error_vested_otc() {
    let mut dapp = deploy();

    dapp.tx!(|_, _, otc, scenario| {
        scenario.next_tx(OWNER);

        let buy_amount = DESIRED_SUI_AMOUNT / 3;

        let (_excess_sui, _meme_coin) = otc.vesting.buy(
            coin::mint_for_testing<SUI>(buy_amount, scenario.ctx()),
            scenario.ctx(),
        );

        abort
    });

    dapp.end();
}

#[test, expected_failure(abort_code = errors::EHasDeadline, location = memez_otc)]
fun test_buy_error_has_deadline() {
    let mut dapp = deploy();

    dapp.tx!(|_, _, otc, scenario| {
        scenario.next_tx(OWNER);

        let buy_amount = DESIRED_SUI_AMOUNT / 3;

        let (_excess_sui, _meme_coin) = otc.deadline.buy(
            coin::mint_for_testing<SUI>(buy_amount, scenario.ctx()),
            scenario.ctx(),
        );

        abort
    });

    dapp.end();
}

#[test, expected_failure(abort_code = errors::EInvalidBuyAmount, location = memez_otc)]
fun test_buy_error_invalid_buy_amount() {
    let mut dapp = deploy();

    dapp.tx!(|_, _, otc, scenario| {
        scenario.next_tx(OWNER);

        let (_excess_sui, _meme_coin) = otc.normal.buy(
            coin::mint_for_testing<SUI>(0, scenario.ctx()),
            scenario.ctx(),
        );

        abort
    });

    dapp.end();
}

#[test, expected_failure(abort_code = errors::EAllMemeSold, location = memez_otc)]
fun test_buy_error_all_meme_sold() {
    let mut dapp = deploy();

    dapp.tx!(|_, _, otc, scenario| {
        scenario.next_tx(OWNER);

        let (amount_in, fee_in) = otc.normal.get_amount_in(SALE_AMOUNT);

        let (_excess_sui, _meme_coin) = otc.normal.buy(
            coin::mint_for_testing<SUI>(amount_in + fee_in, scenario.ctx()),
            scenario.ctx(),
        );

        let (_excess_sui_2, _meme_coin_2) = otc.normal.buy(
            coin::mint_for_testing<SUI>(amount_in + fee_in, scenario.ctx()),
            scenario.ctx(),
        );

        abort
    });

    dapp.end();
}

#[test]
fun test_owner_functions() {
    let mut dapp = deploy();

    dapp.tx!(|config, clock, _, scenario| {
        let meme_coin = coin::mint_for_testing<Meme>(SALE_AMOUNT, scenario.ctx());

        let meme_coin_value = meme_coin.value();

        let mut otc = memez_otc::new(
            config,
            clock,
            meme_coin,
            DESIRED_SUI_AMOUNT,
            RECIPIENT,
            option::none(),
            option::none(),
            scenario.ctx(),
        );

        assert_eq(otc.deadline(), option::none());
        assert_eq(otc.vesting_duration(), option::none());

        scenario.next_tx(OWNER);

        otc.set_deadline(clock, DEADLINE, scenario.ctx());
        otc.set_vesting_duration(VESTING_PERIOD, scenario.ctx());

        assert_eq(otc.deadline(), option::some(DEADLINE));
        assert_eq(otc.vesting_duration(), option::some(VESTING_PERIOD));

        assert_eq(otc.destroy(scenario.ctx()).burn_for_testing(), meme_coin_value);
    });

    dapp.end();
}

#[test, expected_failure(abort_code = errors::ENotOwner, location = memez_otc)]
fun test_set_deadline_not_owner() {
    let mut dapp = deploy();

    dapp.tx!(|_, clock, otc, scenario| {
        scenario.next_tx(ADMIN);

        otc.normal.set_deadline(clock, DEADLINE, scenario.ctx());
    });

    dapp.end();
}

#[test, expected_failure(abort_code = errors::EDeadlineInPast, location = memez_otc)]
fun test_set_deadline_is_in_the_past() {
    let mut dapp = deploy();

    dapp.tx!(|_, clock, otc, scenario| {
        clock.set_for_testing(2);

        scenario.next_tx(OWNER);

        otc.normal.set_deadline(clock, 1, scenario.ctx());
    });

    dapp.end();
}

#[test, expected_failure(abort_code = errors::ENotOwner, location = memez_otc)]
fun test_set_vesting_duration_not_owner() {
    let mut dapp = deploy();

    dapp.tx!(|_, _, otc, scenario| {
        scenario.next_tx(ADMIN);

        otc.normal.set_vesting_duration(VESTING_PERIOD, scenario.ctx());
    });

    dapp.end();
}

#[test, expected_failure(abort_code = errors::ENotOwner, location = memez_otc)]
fun test_destroy_not_owner() {
    let mut dapp = deploy();

    dapp.tx!(|config, clock, _, scenario| {
        scenario.next_tx(OWNER);

        let otc = memez_otc::new(
            config,
            clock,
            coin::mint_for_testing<Meme>(SALE_AMOUNT, scenario.ctx()),
            DESIRED_SUI_AMOUNT,
            RECIPIENT,
            option::none(),
            option::none(),
            scenario.ctx(),
        );

        scenario.next_tx(ADMIN);

        otc.destroy(scenario.ctx()).burn_for_testing();
    });

    dapp.end();
}


#[test, expected_failure(abort_code = errors::EZeroPrice, location = memez_otc)]
fun test_new_zero_price() {
    let mut dapp = deploy();

    dapp.tx!(|config, clock, _, scenario| {
        let _memez_otc = memez_otc::new(
            config,
            clock,
            coin::mint_for_testing<Meme>(SALE_AMOUNT, scenario.ctx()),
            0,
            RECIPIENT,
            option::none(),
            option::none(),
            scenario.ctx(),
        );

        abort
    });

    dapp.end();
}

#[test, expected_failure(abort_code = errors::EInvalidRecipient, location = memez_otc)]
fun test_new_invalid_recipient() {
    let mut dapp = deploy();

    dapp.tx!(|config, clock, _, scenario| {
        let _memez_otc = memez_otc::new(
            config,
            clock,
            coin::mint_for_testing<Meme>(SALE_AMOUNT, scenario.ctx()),
            1,
            @0x0,
            option::none(),
            option::none(),
            scenario.ctx(),
        );

        abort
    });

    dapp.end();
}

#[test, expected_failure(abort_code = errors::EDeadlineInPast, location = memez_otc)]
fun test_new_deadline_in_past() {
    let mut dapp = deploy();

    dapp.tx!(|config, clock, _, scenario| {
        clock.set_for_testing(2);

        let _memez_otc = memez_otc::new(
            config,
            clock,
            coin::mint_for_testing<Meme>(SALE_AMOUNT, scenario.ctx()),
            1,
            RECIPIENT,
            option::none(),
            option::some(1),
            scenario.ctx(),
        );

        abort
    });

    dapp.end();
}

macro fun tx($dapp: &mut Dapp, $f: |&mut MemezOTCConfig, &mut Clock, &mut OTC, &mut Scenario|) {
    let dapp = $dapp;
    let mut config = dapp.config.pop_back();
    let mut scenario = dapp.scenario.pop_back();
    let mut otc = dapp.otc.pop_back();
    let mut clock = dapp.clock.pop_back();

    $f(&mut config, &mut clock, &mut otc, &mut scenario);

    dapp.scenario.push_back(scenario);
    dapp.config.push_back(config);
    dapp.otc.push_back(otc);
    dapp.clock.push_back(clock);
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

    let deadline_otc = memez_otc::new(
        &config,
        &clock,
        coin::mint_for_testing<Meme>(SALE_AMOUNT, scenario.ctx()),
        DESIRED_SUI_AMOUNT,
        RECIPIENT,
        option::none(),
        option::some(DEADLINE),
        scenario.ctx(),
    );

    let vesting_otc = memez_otc::new(
        &config,
        &clock,
        coin::mint_for_testing<Meme>(SALE_AMOUNT, scenario.ctx()),
        DESIRED_SUI_AMOUNT,
        RECIPIENT,
        option::some(VESTING_PERIOD),
        option::none(),
        scenario.ctx(),
    );

    let deadline_vesting_otc = memez_otc::new(
        &config,
        &clock,
        coin::mint_for_testing<Meme>(SALE_AMOUNT, scenario.ctx()),
        DESIRED_SUI_AMOUNT,
        RECIPIENT,
        option::some(VESTING_PERIOD),
        option::some(DEADLINE),
        scenario.ctx(),
    );

    Dapp {
        scenario: vector[scenario],
        config: vector[config],
        otc: vector[
            OTC {
                normal: otc,
                deadline: deadline_otc,
                vesting: vesting_otc,
                deadline_vesting: deadline_vesting_otc,
            },
        ],
        clock: vector[clock],
    }
}

public fun end(dapp: Dapp) {
    destroy(dapp);
}
