#[test_only]
module memez_fun::memez_fixed_rate_tests;

use interest_bps::bps;
use memez_fun::{memez_distributor, memez_errors, memez_fees, memez_fixed_rate};
use sui::{
    balance,
    coin::{mint_for_testing, Coin},
    sui::SUI,
    test_scenario as ts,
    test_utils::{assert_eq, destroy}
};

public struct Meme()

const BPS_MAX: u64 = 10_000;

const REFERRER_ADDRESS: address = @0x7;

#[test]
fun test_new() {
    let sui_raise_amount = 1000;
    let meme_balance_value = 5000;

    let meme_balance = balance::create_for_testing<Meme>(meme_balance_value);

    let mut fixed_rate = memez_fixed_rate::new<Meme, SUI>(
        sui_raise_amount,
        meme_balance,
        memez_fees::new_percentage_fee(
            40,
            memez_distributor::new(
                vector[@0x0],
                vector[BPS_MAX],
            ),
        ),
        memez_fees::new_percentage_fee(
            30,
            memez_distributor::new(
                vector[@0x0],
                vector[BPS_MAX],
            ),
        ),
        bps::new(5),
        bps::new(10),
    );

    assert_eq(fixed_rate.quote_raise_amount(), sui_raise_amount);
    assert_eq(fixed_rate.memez_fun(), @0x0);
    assert_eq(fixed_rate.meme_sale_amount(), meme_balance_value);
    assert_eq(fixed_rate.meme_balance().value(), meme_balance_value);
    assert_eq(fixed_rate.quote_balance().value(), 0);
    assert_eq(fixed_rate.meme_swap_fee().value(), 40);
    assert_eq(fixed_rate.quote_swap_fee().value(), 30);
    assert_eq(fixed_rate.meme_referrer_fee(), bps::new(5));
    assert_eq(fixed_rate.quote_referrer_fee(), bps::new(10));

    fixed_rate.set_memez_fun(@0x1);

    assert_eq(fixed_rate.memez_fun(), @0x1);

    destroy(fixed_rate);
}

#[test]
fun test_pump() {
    let mut ctx = tx_context::dummy();

    let sui_raise_amount = 1000;
    let meme_balance_value = 5000;

    let swap_fee = memez_fees::new_percentage_fee(
        0,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let meme_balance = balance::create_for_testing<Meme>(meme_balance_value);

    let mut fixed_rate = memez_fixed_rate::new(
        sui_raise_amount,
        meme_balance,
        swap_fee,
        swap_fee,
        bps::new(0),
        bps::new(0),
    );

    let amount_in = 200;

    let amounts = fixed_rate.pump_amount(amount_in, 0);

    let (can_migrate, excess_sui_coin, meme_coin_out) = fixed_rate.pump(
        mint_for_testing<SUI>(amount_in, &mut ctx),
        option::none(),
        &mut ctx,
    );

    assert_eq(can_migrate, false);
    assert_eq(amounts[0], 0);
    assert_eq(excess_sui_coin.burn_for_testing(), 0);
    assert_eq(meme_coin_out.burn_for_testing(), 1000);
    assert_eq(amounts[2], swap_fee.calculate(amount_in));

    let amount_in = 400;

    let amounts = fixed_rate.pump_amount(amount_in, 0);

    let (can_migrate, excess_sui_coin, meme_coin_out) = fixed_rate.pump(
        mint_for_testing<SUI>(amount_in, &mut ctx),
        option::none(),
        &mut ctx,
    );

    assert_eq(can_migrate, false);
    assert_eq(amounts[0], 0);
    assert_eq(excess_sui_coin.burn_for_testing(), 0);
    assert_eq(meme_coin_out.burn_for_testing(), 2000);

    let amount_in = 500;

    let amounts = fixed_rate.pump_amount(amount_in, 0);

    let (can_migrate, excess_sui_coin, meme_coin_out) = fixed_rate.pump(
        mint_for_testing<SUI>(amount_in, &mut ctx),
        option::none(),
        &mut ctx,
    );

    assert_eq(can_migrate, true);
    assert_eq(amounts[0], 100);
    assert_eq(excess_sui_coin.burn_for_testing(), 100);
    assert_eq(meme_coin_out.burn_for_testing(), 2000);

    let amount_in = 500;

    let amounts = fixed_rate.pump_amount(amount_in, 0);

    let (can_migrate, excess_sui_coin, meme_coin_out) = fixed_rate.pump(
        mint_for_testing<SUI>(amount_in, &mut ctx),
        option::none(),
        &mut ctx,
    );

    assert_eq(can_migrate, true);
    assert_eq(amounts[0], 500);
    assert_eq(excess_sui_coin.burn_for_testing(), 500);
    assert_eq(meme_coin_out.burn_for_testing(), 0);

    destroy(fixed_rate);
}

#[test]
fun test_dump() {
    let mut ctx = tx_context::dummy();

    let sui_raise_amount = 1000;
    let meme_balance_value = 5000;

    let meme_swap_fee = memez_fees::new_percentage_fee(
        40,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let quote_swap_fee = memez_fees::new_percentage_fee(
        30,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let meme_balance = balance::create_for_testing<Meme>(meme_balance_value);

    let mut fixed_rate = memez_fixed_rate::new(
        sui_raise_amount,
        meme_balance,
        meme_swap_fee,
        quote_swap_fee,
        bps::new(0),
        bps::new(0),
    );

    let (_, excess_sui_coin, meme_coin_out) = fixed_rate.pump(
        mint_for_testing<SUI>(1000, &mut ctx),
        option::none(),
        &mut ctx,
    );

    excess_sui_coin.burn_for_testing();
    meme_coin_out.burn_for_testing();

    let amount_in = 1000;

    let sui_coin_out = fixed_rate.dump(
        mint_for_testing<Meme>(amount_in, &mut ctx),
        option::none(),
        &mut ctx,
    );

    let pre_fee_amount_out = 200 * (amount_in -  meme_swap_fee.calculate(amount_in)) / 1000;

    assert_eq(
        sui_coin_out.burn_for_testing(),
        pre_fee_amount_out - quote_swap_fee.calculate(pre_fee_amount_out),
    );

    let amount_in = 1000;

    let sui_coin_out = fixed_rate.dump(
        mint_for_testing<Meme>(amount_in, &mut ctx),
        option::none(),
        &mut ctx,
    );

    let pre_fee_amount_out = 200 * (amount_in -  quote_swap_fee.calculate(amount_in)) / 1000;

    assert_eq(
        sui_coin_out.burn_for_testing(),
        pre_fee_amount_out - meme_swap_fee.calculate(pre_fee_amount_out),
    );

    let amount_in = 2000;

    let sui_coin_out = fixed_rate.dump(
        mint_for_testing<Meme>(amount_in, &mut ctx),
        option::none(),
        &mut ctx,
    );

    let pre_fee_amount_out = 400 * (amount_in -  meme_swap_fee.calculate(amount_in)) / 2000;

    assert_eq(
        sui_coin_out.burn_for_testing(),
        pre_fee_amount_out - quote_swap_fee.calculate(pre_fee_amount_out),
    );

    let amount_in = 1000;

    let sui_coin_out = fixed_rate.dump(
        mint_for_testing<Meme>(amount_in, &mut ctx),
        option::none(),
        &mut ctx,
    );

    let pre_fee_amount_out = 200 * (amount_in -  meme_swap_fee.calculate(amount_in)) / 1000;

    assert_eq(
        sui_coin_out.burn_for_testing(),
        pre_fee_amount_out - quote_swap_fee.calculate(pre_fee_amount_out),
    );

    let amount_in = 2000;

    let amounts = fixed_rate.dump_amount(amount_in, 0);

    let sui_coin_out = fixed_rate.dump(
        mint_for_testing<Meme>(amount_in, &mut ctx),
        option::none(),
        &mut ctx,
    );

    assert_eq(sui_coin_out.burn_for_testing(), amounts[0]);

    let amounts = fixed_rate.dump_amount(amount_in, 0);

    let sui_coin_out = fixed_rate.dump(
        mint_for_testing<Meme>(amount_in, &mut ctx),
        option::none(),
        &mut ctx,
    );

    assert_eq(amounts[0], 0);
    assert_eq(sui_coin_out.burn_for_testing(), 0);

    destroy(fixed_rate);
}

#[test]
fun test_pump_and_dump_amounts() {
    let meme_swap_fee = memez_fees::new_percentage_fee(
        40,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let quote_swap_fee = memez_fees::new_percentage_fee(
        30,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let mut fixed_rate = memez_fixed_rate::new<Meme, SUI>(
        1000,
        balance::create_for_testing<Meme>(5000),
        meme_swap_fee,
        quote_swap_fee,
        bps::new(0),
        bps::new(0),
    );

    let amounts = fixed_rate.pump_amount(400, 0);

    let amount_pre_fee = 5000 * (400 - quote_swap_fee.calculate(400)) / 1000;

    assert_eq(amounts[0], 0);
    assert_eq(amounts[1], amount_pre_fee - meme_swap_fee.calculate(amount_pre_fee));
    assert_eq(amounts[2], quote_swap_fee.calculate(400));
    assert_eq(amounts[3], meme_swap_fee.calculate(amount_pre_fee));

    let amounts = fixed_rate.pump_amount(0, 0);

    assert_eq(amounts, vector[0, 0, 0, 0]);

    let amounts = fixed_rate.dump_amount(0, 0);

    assert_eq(amounts, vector[0, 0, 0]);

    let amounts = fixed_rate.dump_amount(1000, 0);

    assert_eq(amounts[0], 0);
    assert_eq(amounts[1], meme_swap_fee.calculate(1000));
    assert_eq(amounts[2], 0);

    fixed_rate.quote_balance_mut().join(balance::create_for_testing<SUI>(1000));

    let amounts = fixed_rate.dump_amount(1000, 0);

    let amount_pre_fee = 1000 * (1000 - meme_swap_fee.calculate(1000)) / 5000;

    assert_eq(amounts[0], amount_pre_fee - quote_swap_fee.calculate(amount_pre_fee));
    assert_eq(amounts[1], meme_swap_fee.calculate(1000));
    assert_eq(amounts[2], quote_swap_fee.calculate(amount_pre_fee));

    destroy(fixed_rate);

    let mut fixed_rate = memez_fixed_rate::new<Meme, SUI>(
        1000,
        balance::create_for_testing<Meme>(5000),
        memez_fees::new_percentage_fee(
            0,
            memez_distributor::new(
                vector[@0x0],
                vector[BPS_MAX],
            ),
        ),
        memez_fees::new_percentage_fee(
            0,
            memez_distributor::new(
                vector[@0x0],
                vector[BPS_MAX],
            ),
        ),
        bps::new(0),
        bps::new(0),
    );

    let amounts = fixed_rate.pump_amount(500, 0);

    assert_eq(amounts[0], 0);
    assert_eq(amounts[1], 5000 * 500 / 1000);
    assert_eq(amounts[2], 0);

    let amounts = fixed_rate.pump_amount(1100, 0);

    assert_eq(amounts[0], 100);
    assert_eq(amounts[1], 5000);
    assert_eq(amounts[2], 0);

    let amounts = fixed_rate.dump_amount(1000, 0);

    assert_eq(amounts[0], 0);
    assert_eq(amounts[1], 0);

    fixed_rate.quote_balance_mut().join(balance::create_for_testing<SUI>(1000));

    let amounts = fixed_rate.dump_amount(1000, 0);

    assert_eq(amounts[0], 1000 * 1000 / 5000);
    assert_eq(amounts[1], 0);

    destroy(fixed_rate);
}

#[test]
fun test_pump_and_dump_amounts_with_extra_meme_sale_amount() {
    let meme_swap_fee = memez_fees::new_percentage_fee(
        40,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let quote_swap_fee = memez_fees::new_percentage_fee(
        30,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let mut fixed_rate = memez_fixed_rate::new<Meme, SUI>(
        1000,
        balance::create_for_testing<Meme>(5000),
        meme_swap_fee,
        quote_swap_fee,
        bps::new(0),
        bps::new(0),
    );

    let amounts = fixed_rate.pump_amount(400, 1000);

    let amount_pre_fee = (5000 + 1000) * (400 - quote_swap_fee.calculate(400)) / 1000;

    assert_eq(amounts[0], 0);
    assert_eq(amounts[1], amount_pre_fee - meme_swap_fee.calculate(amount_pre_fee));
    assert_eq(amounts[2], quote_swap_fee.calculate(400));
    assert_eq(amounts[3], meme_swap_fee.calculate(amount_pre_fee));

    let amounts = fixed_rate.pump_amount(0, 1000);

    assert_eq(amounts, vector[0, 0, 0, 0]);

    let amounts = fixed_rate.dump_amount(0, 1000);

    assert_eq(amounts, vector[0, 0, 0]);

    let amounts = fixed_rate.dump_amount(1000, 500);

    assert_eq(amounts[0], 0);
    assert_eq(amounts[1], meme_swap_fee.calculate(1000));
    assert_eq(amounts[2], 0);

    fixed_rate.quote_balance_mut().join(balance::create_for_testing<SUI>(1000));

    let amounts = fixed_rate.dump_amount(1000, 1000);

    let amount_pre_fee = 1000 * (1000 - meme_swap_fee.calculate(1000)) / (5000 + 1000);

    assert_eq(amounts[0], amount_pre_fee - quote_swap_fee.calculate(amount_pre_fee));
    assert_eq(amounts[1], meme_swap_fee.calculate(1000));
    assert_eq(amounts[2], quote_swap_fee.calculate(amount_pre_fee));

    destroy(fixed_rate);

    let mut fixed_rate = memez_fixed_rate::new<Meme, SUI>(
        1000,
        balance::create_for_testing<Meme>(5000),
        memez_fees::new_percentage_fee(
            0,
            memez_distributor::new(
                vector[@0x0],
                vector[BPS_MAX],
            ),
        ),
        memez_fees::new_percentage_fee(
            0,
            memez_distributor::new(
                vector[@0x0],
                vector[BPS_MAX],
            ),
        ),
        bps::new(0),
        bps::new(0),
    );

    let amounts = fixed_rate.pump_amount(500, 500);

    assert_eq(amounts[0], 0);
    assert_eq(amounts[1], (5000 + 500) * 500 / 1000);
    assert_eq(amounts[2], 0);
    assert_eq(amounts[3], 0);

    let amounts = fixed_rate.pump_amount(1100, 500);

    assert_eq(amounts[0], 100);
    assert_eq(amounts[1], 5500);
    assert_eq(amounts[2], 0);
    assert_eq(amounts[3], 0);

    let amounts = fixed_rate.dump_amount(1000, 500);

    assert_eq(amounts[0], 0);
    assert_eq(amounts[1], 0);
    assert_eq(amounts[2], 0);

    fixed_rate.quote_balance_mut().join(balance::create_for_testing<SUI>(1000));

    let amounts = fixed_rate.dump_amount(1000, 500);

    assert_eq(amounts[0], 1000 * 1000 / (5000 + 500));
    assert_eq(amounts[1], 0);
    assert_eq(amounts[2], 0);

    destroy(fixed_rate);
}

#[test]
fun test_increase_meme_available() {
    let mut fixed_rate = memez_fixed_rate::new<Meme, SUI>(
        1000,
        balance::create_for_testing<Meme>(5000),
        memez_fees::new_percentage_fee(
            40,
            memez_distributor::new(
                vector[@0x0],
                vector[BPS_MAX],
            ),
        ),
        memez_fees::new_percentage_fee(
            30,
            memez_distributor::new(
                vector[@0x0],
                vector[BPS_MAX],
            ),
        ),
        bps::new(0),
        bps::new(0),
    );
    assert_eq(fixed_rate.meme_sale_amount(), 5000);
    assert_eq(fixed_rate.meme_balance().value(), 5000);

    fixed_rate.increase_meme_available(balance::create_for_testing(1000));

    assert_eq(fixed_rate.meme_sale_amount(), 6000);
    assert_eq(fixed_rate.meme_balance().value(), 6000);

    destroy(fixed_rate);
}

#[test]
fun test_pump_with_referrer() {
    let mut scenario = ts::begin(REFERRER_ADDRESS);

    let sui_raise_amount = 10_000;
    let meme_balance_value = 5000;

    let meme_balance = balance::create_for_testing<Meme>(meme_balance_value);

    let meme_swap_fee = memez_fees::new_percentage_fee(
        300,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let quote_swap_fee = memez_fees::new_percentage_fee(
        200,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let meme_discount = bps::new(200);
    let quote_discount = bps::new(100);

    let mut fixed_rate = memez_fixed_rate::new(
        sui_raise_amount,
        meme_balance,
        meme_swap_fee,
        quote_swap_fee,
        meme_discount,
        quote_discount,
    );

    let amount_in = 1_000;

    let amounts = fixed_rate.pump_amount(amount_in, 0);

    let (can_migrate, excess_sui_coin, meme_coin_out) = fixed_rate.pump(
        mint_for_testing<SUI>(amount_in, scenario.ctx()),
        option::some(REFERRER_ADDRESS),
        scenario.ctx(),
    );

    assert_eq(can_migrate, false);
    assert_eq(amounts[0], 0);
    assert_eq(excess_sui_coin.burn_for_testing(), 0);
    assert_eq(
        meme_coin_out.burn_for_testing(),
        490 - meme_swap_fee.calculate_with_discount(meme_discount, 490) - meme_discount.calc_up(490),
    );
    assert_eq(amounts[2], quote_swap_fee.calculate(amount_in));

    scenario.next_tx(REFERRER_ADDRESS);

    let quote_referrer_coin = scenario.take_from_sender<Coin<SUI>>();
    let meme_referrer_coin = scenario.take_from_sender<Coin<Meme>>();

    assert_eq(quote_referrer_coin.burn_for_testing(), quote_discount.calc_up(amount_in));
    assert_eq(meme_referrer_coin.burn_for_testing(), meme_discount.calc_up(490));

    destroy(fixed_rate);
    scenario.end();
}

#[test]
fun test_dump_with_referrer() {
    let mut scenario = ts::begin(REFERRER_ADDRESS);

    let sui_raise_amount = 10_000;
    let meme_balance_value = 5000;

    let meme_balance = balance::create_for_testing<Meme>(meme_balance_value);

    let meme_swap_fee = memez_fees::new_percentage_fee(
        300,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let quote_swap_fee = memez_fees::new_percentage_fee(
        200,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let meme_discount = bps::new(200);
    let quote_discount = bps::new(100);

    let mut fixed_rate = memez_fixed_rate::new(
        sui_raise_amount,
        meme_balance,
        meme_swap_fee,
        quote_swap_fee,
        meme_discount,
        quote_discount,
    );

    let amount_in = 1_000;

    let (_, excess_sui_coin, meme_coin_out) = fixed_rate.pump(
        mint_for_testing<SUI>(amount_in, scenario.ctx()),
        option::some(REFERRER_ADDRESS),
        scenario.ctx(),
    );

    excess_sui_coin.burn_for_testing();
    meme_coin_out.burn_for_testing();

    scenario.next_tx(REFERRER_ADDRESS);

    let quote_referrer_coin = scenario.take_from_sender<Coin<SUI>>();
    let meme_referrer_coin = scenario.take_from_sender<Coin<Meme>>();

    quote_referrer_coin.burn_for_testing();
    meme_referrer_coin.burn_for_testing();

    let amount_in = 500;

    let sui_coin_out = fixed_rate.dump(
        mint_for_testing<Meme>(amount_in, scenario.ctx()),
        option::some(REFERRER_ADDRESS),
        scenario.ctx(),
    );

    let amount_out_before_fee = 485 * 2;

    let quote_discount_amount = quote_discount.calc_up(amount_out_before_fee);

    let amount_out = (
        amount_out_before_fee -  quote_swap_fee.calculate_with_discount(quote_discount, amount_out_before_fee) - quote_discount_amount,
    );

    assert_eq(
        sui_coin_out.burn_for_testing(),
        amount_out,
    );

    scenario.next_tx(REFERRER_ADDRESS);

    let quote_referrer_coin = scenario.take_from_sender<Coin<SUI>>();
    let meme_referrer_coin = scenario.take_from_sender<Coin<Meme>>();

    assert_eq(
        quote_referrer_coin.burn_for_testing(),
        quote_discount.calc_up(amount_out_before_fee),
    );
    assert_eq(meme_referrer_coin.burn_for_testing(), meme_discount.calc_up(amount_in));

    destroy(fixed_rate);
    scenario.end();
}

#[test, expected_failure(abort_code = memez_errors::EZeroCoin, location = memez_fixed_rate)]
fun test_pump_zero_coin() {
    let mut ctx = tx_context::dummy();

    let sui_raise_amount = 1000;
    let meme_balance_value = 5000;

    let meme_balance = balance::create_for_testing<Meme>(meme_balance_value);

    let swap_fee = memez_fees::new_percentage_fee(
        300,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let mut fixed_rate = memez_fixed_rate::new(
        sui_raise_amount,
        meme_balance,
        swap_fee,
        swap_fee,
        bps::new(0),
        bps::new(0),
    );

    let (_, excess_sui_coin, meme_coin_out) = fixed_rate.pump(
        mint_for_testing<SUI>(0, &mut ctx),
        option::none(),
        &mut ctx,
    );

    meme_coin_out.burn_for_testing();
    excess_sui_coin.burn_for_testing();

    destroy(fixed_rate);
}

#[test, expected_failure(abort_code = memez_errors::EZeroCoin, location = memez_fixed_rate)]
fun test_dump_zero_coin() {
    let mut ctx = tx_context::dummy();

    let sui_raise_amount = 1000;
    let meme_balance_value = 5000;

    let meme_balance = balance::create_for_testing<Meme>(meme_balance_value);

    let swap_fee = memez_fees::new_percentage_fee(
        30,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let mut fixed_rate = memez_fixed_rate::new(
        sui_raise_amount,
        meme_balance,
        swap_fee,
        swap_fee,
        bps::new(0),
        bps::new(0),
    );

    let (_, excess_sui_coin, meme_coin_out) = fixed_rate.pump(
        mint_for_testing<SUI>(1000, &mut ctx),
        option::none(),
        &mut ctx,
    );

    excess_sui_coin.burn_for_testing();
    meme_coin_out.burn_for_testing();

    fixed_rate
        .dump(
            mint_for_testing<Meme>(0, &mut ctx),
            option::none(),
            &mut ctx,
        )
        .burn_for_testing();

    abort
}

#[test, expected_failure]
fun test_zero_quote_raise_amount() {
    let swap_fee = memez_fees::new_percentage_fee(
        30,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let fixed_rate = memez_fixed_rate::new<Meme, SUI>(
        0,
        balance::create_for_testing<Meme>(1),
        swap_fee,
        swap_fee,
        bps::new(0),
        bps::new(0),
    );

    destroy(fixed_rate);
}
