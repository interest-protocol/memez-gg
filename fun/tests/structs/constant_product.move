#[test_only]
module memez_fun::memez_constant_product_tests;

use interest_bps::bps;
use interest_constant_product::constant_product::get_amount_out;
use ipx_coin_standard::ipx_coin_standard;
use memez_fun::{memez_burner, memez_constant_product, memez_distributor, memez_errors, memez_fees};
use sui::{
    balance,
    coin::{Self, mint_for_testing, Coin},
    sui::SUI,
    test_scenario as ts,
    test_utils::{assert_eq, destroy}
};

public struct Meme()

public struct Quote()

const BURN_TAX: u64 = 2_000;

const BPS_MAX: u64 = 10_000;

const REFERRER_ADDRESS: address = @0x7;

#[test]
fun test_new() {
    let virtual_liquidity = 100;
    let target_quote_liquidity = 1100;
    let meme_balance_value = 5000;

    let meme_swap_fee = 40;
    let quote_swap_fee = 30;

    let meme_referrer_fee = bps::new(10);
    let quote_referrer_fee = bps::new(5);

    let cp = memez_constant_product::new<Meme, Quote>(
        virtual_liquidity,
        target_quote_liquidity,
        balance::create_for_testing<Meme>(meme_balance_value),
        memez_fees::new_percentage_fee(
            meme_swap_fee,
            memez_distributor::new(
                vector[@0x0],
                vector[BPS_MAX],
            ),
        ),
        memez_fees::new_percentage_fee(
            quote_swap_fee,
            memez_distributor::new(
                vector[@0x0],
                vector[BPS_MAX],
            ),
        ),
        meme_referrer_fee,
        quote_referrer_fee,
        BURN_TAX,
    );

    assert_eq(cp.virtual_liquidity(), virtual_liquidity);
    assert_eq(cp.target_quote_liquidity(), target_quote_liquidity);
    assert_eq(cp.meme_balance().value(), meme_balance_value);
    assert_eq(cp.burner().fee().value(), BURN_TAX);
    assert_eq(cp.burner().target_liquidity(), target_quote_liquidity);
    assert_eq(cp.meme_swap_fee().value(), meme_swap_fee);
    assert_eq(cp.quote_swap_fee().value(), quote_swap_fee);
    assert_eq(cp.meme_referrer_fee().value(), meme_referrer_fee.value());
    assert_eq(cp.quote_referrer_fee().value(), quote_referrer_fee.value());

    destroy(cp);
}

#[test]
fun test_set_memez_fun() {
    let mut cp = memez_constant_product::new<Meme, Quote>(
        100,
        1100,
        balance::create_for_testing<Meme>(5000),
        memez_fees::new_percentage_fee(
            30,
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
        BURN_TAX,
    );

    assert_eq(cp.memez_fun(), @0x0);

    cp.set_memez_fun(@0x1);

    assert_eq(cp.memez_fun(), @0x1);

    destroy(cp);
}

#[test]
fun test_pump() {
    let mut ctx = tx_context::dummy();

    let virtual_liquidity = 100;
    let target_sui_liquidity = 1100;
    let meme_balance_value = 5000;

    let swap_fee = memez_fees::new_percentage_fee(
        0,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let mut cp = memez_constant_product::new(
        virtual_liquidity,
        target_sui_liquidity,
        balance::create_for_testing<Meme>(meme_balance_value),
        swap_fee,
        swap_fee,
        bps::new(0),
        bps::new(0),
        BURN_TAX,
    );

    let amount_in = 250;

    let amount_out = get_amount_out!(amount_in, virtual_liquidity, meme_balance_value);

    let amounts = cp.pump_amount(amount_in);

    let (can_migrate, coin_meme_out) = cp.pump(
        mint_for_testing<SUI>(amount_in, &mut ctx),
        option::none(),
        0,
        &mut ctx,
    );

    assert_eq(can_migrate, false);
    assert_eq(coin_meme_out.value(), amounts[0]);
    assert_eq(amounts[1], swap_fee.calculate(amount_in));
    assert_eq(coin_meme_out.burn_for_testing(), amount_out);
    assert_eq(cp.quote_balance().value(), amount_in);
    assert_eq(cp.virtual_liquidity(), virtual_liquidity);
    assert_eq(cp.meme_balance().value(), meme_balance_value - amount_out);

    let meme_balance_value = cp.meme_balance().value();

    let new_sui_balance = amount_in;

    let amount_in = target_sui_liquidity - amount_in;

    let amount_out = get_amount_out!(
        amount_in,
        virtual_liquidity + new_sui_balance,
        meme_balance_value,
    );

    let amounts = cp.pump_amount(amount_in);

    let (can_migrate, coin_meme_out) = cp.pump(
        mint_for_testing<SUI>(amount_in, &mut ctx),
        option::none(),
        0,
        &mut ctx,
    );

    assert_eq(can_migrate, true);
    assert_eq(coin_meme_out.value(), amounts[0]);
    assert_eq(amounts[1], swap_fee.calculate(amount_in));
    assert_eq(coin_meme_out.burn_for_testing(), amount_out);
    assert_eq(cp.quote_balance().value(), amount_in + new_sui_balance);
    assert_eq(cp.virtual_liquidity(), virtual_liquidity);
    assert_eq(cp.meme_balance().value(), meme_balance_value - amount_out);

    destroy(cp);
}

#[test]
fun test_pump_with_fee() {
    let mut ctx = tx_context::dummy();

    let virtual_liquidity = 100;
    let target_sui_liquidity = 1100;
    let meme_balance_value = 5000;

    let quote_swap_fee = memez_fees::new_percentage_fee(
        30,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let meme_swap_fee = memez_fees::new_percentage_fee(
        0,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let mut cp = memez_constant_product::new(
        virtual_liquidity,
        target_sui_liquidity,
        balance::create_for_testing<Meme>(meme_balance_value),
        meme_swap_fee,
        quote_swap_fee,
        bps::new(0),
        bps::new(0),
        BURN_TAX,
    );

    let amount_in = 250;

    let quote_swap_fee_amount = quote_swap_fee.calculate(amount_in);

    let amount_out = get_amount_out!(
        amount_in - quote_swap_fee_amount,
        virtual_liquidity,
        meme_balance_value,
    );

    let amounts = cp.pump_amount(amount_in);

    let (can_migrate, coin_meme_out) = cp.pump(
        mint_for_testing<SUI>(amount_in, &mut ctx),
        option::none(),
        0,
        &mut ctx,
    );

    let meme_swap_fee_amount_out = meme_swap_fee.calculate(amount_out);

    assert_eq(can_migrate, false);
    assert_eq(coin_meme_out.value(), amounts[0]);
    assert_eq(amounts[1], quote_swap_fee.calculate(amount_in));
    assert_eq(coin_meme_out.burn_for_testing(), amount_out - meme_swap_fee_amount_out);
    assert_eq(cp.quote_balance().value(), amount_in - quote_swap_fee_amount);
    assert_eq(cp.virtual_liquidity(), virtual_liquidity);
    assert_eq(cp.meme_balance().value(), meme_balance_value - amount_out);
    assert_eq(meme_swap_fee_amount_out, amounts[2]);

    let meme_balance_value = cp.meme_balance().value();

    let new_sui_balance = amount_in - quote_swap_fee_amount;

    let amount_in = target_sui_liquidity - amount_in;

    let quote_swap_fee_amount = quote_swap_fee.calculate(amount_in);

    let amount_out = get_amount_out!(
        amount_in - quote_swap_fee_amount,
        virtual_liquidity + new_sui_balance,
        meme_balance_value,
    );

    let amounts = cp.pump_amount(amount_in);

    let (can_migrate, coin_meme_out) = cp.pump(
        mint_for_testing<SUI>(amount_in, &mut ctx),
        option::none(),
        0,
        &mut ctx,
    );

    let meme_swap_fee_amount_out = meme_swap_fee.calculate(amount_out);

    assert_eq(can_migrate, false);
    assert_eq(coin_meme_out.value(), amounts[0]);
    assert_eq(amounts[1], quote_swap_fee.calculate(amount_in));
    assert_eq(coin_meme_out.burn_for_testing(), amount_out - meme_swap_fee_amount_out);
    assert_eq(cp.quote_balance().value(), amount_in + new_sui_balance - quote_swap_fee_amount);
    assert_eq(cp.virtual_liquidity(), virtual_liquidity);
    assert_eq(cp.meme_balance().value(), meme_balance_value - amount_out);
    assert_eq(meme_swap_fee_amount_out, amounts[2]);

    destroy(cp);
}

#[test]
fun test_dump() {
    let mut ctx = tx_context::dummy();

    let virtual_liquidity = 100;
    let target_sui_liquidity = 1100;
    let meme_balance_value = 5000;

    let swap_fee = memez_fees::new_percentage_fee(
        0,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let mut meme_treasury_cap = coin::create_treasury_cap_for_testing<Meme>(&mut ctx);

    let mut cp = memez_constant_product::new(
        virtual_liquidity,
        target_sui_liquidity,
        meme_treasury_cap.mint(meme_balance_value, &mut ctx).into_balance(),
        swap_fee,
        swap_fee,
        bps::new(0),
        bps::new(0),
        0,
    );

    let (mut ipx_treasury, mut witness) = ipx_coin_standard::new(meme_treasury_cap, &mut ctx);

    witness.allow_public_burn(
        &mut ipx_treasury,
    );

    let sui_amount_in = 500;

    let (_, coin_meme_out) = cp.pump(
        mint_for_testing<SUI>(sui_amount_in, &mut ctx),
        option::none(),
        0,
        &mut ctx,
    );

    let meme_coin_out_value = coin_meme_out.value();

    let amounts = cp.dump_amount(meme_coin_out_value);

    let amount_out = get_amount_out!(
        meme_coin_out_value,
        cp.meme_balance().value(),
        cp.quote_balance().value() + virtual_liquidity,
    );

    let sui_coin_out = cp.dump(
        &mut ipx_treasury,
        coin_meme_out,
        option::none(),
        amounts[0],
        &mut ctx,
    );

    assert_eq(amount_out, amounts[0]);
    assert_eq(0, amounts[1]);
    assert_eq(0, amounts[2]);
    assert_eq(0, amounts[3]);
    assert_eq(ipx_treasury.total_supply<Meme>(), meme_balance_value);

    assert_eq(cp.quote_balance().value(), sui_amount_in - amounts[0]);
    assert_eq(cp.meme_balance().value(), meme_balance_value);

    sui_coin_out.burn_for_testing();

    let amount_out = get_amount_out!(
        meme_coin_out_value,
        cp.meme_balance().value(),
        cp.quote_balance().value() + virtual_liquidity,
    );

    cp
        .dump(
            &mut ipx_treasury,
            coin::mint_for_testing<Meme>(meme_coin_out_value, &mut ctx),
            option::none(),
            0,
            &mut ctx,
        )
        .burn_for_testing();

    assert_eq(amount_out != 0, true);

    let amounts = cp.dump_amount(meme_coin_out_value);

    let amount_out = get_amount_out!(
        meme_coin_out_value,
        cp.meme_balance().value(),
        cp.quote_balance().value() + virtual_liquidity,
    );

    assert_eq(amounts[0], amount_out.min(cp.quote_balance().value()));
    assert_eq(amount_out != 0, true);
    assert_eq(cp.quote_balance().value(), 0);

    cp
        .dump(
            &mut ipx_treasury,
            coin::mint_for_testing<Meme>(meme_coin_out_value, &mut ctx),
            option::none(),
            0,
            &mut ctx,
        )
        .destroy_zero();

    destroy(witness);
    destroy(ipx_treasury);
    destroy(cp);
}

#[test]
fun test_dump_with_fee() {
    let mut ctx = tx_context::dummy();

    let virtual_liquidity = 100;
    let target_sui_liquidity = 1100;
    let meme_balance_value = 5000;

    let quote_swap_fee = memez_fees::new_percentage_fee(
        30,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let meme_swap_fee = memez_fees::new_percentage_fee(
        50,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let burner = memez_burner::new(BURN_TAX, target_sui_liquidity);

    let mut meme_treasury_cap = coin::create_treasury_cap_for_testing<Meme>(&mut ctx);

    let mut cp = memez_constant_product::new(
        virtual_liquidity,
        target_sui_liquidity,
        meme_treasury_cap.mint(meme_balance_value, &mut ctx).into_balance(),
        meme_swap_fee,
        quote_swap_fee,
        bps::new(0),
        bps::new(0),
        BURN_TAX,
    );

    let (mut ipx_treasury, mut witness) = ipx_coin_standard::new(meme_treasury_cap, &mut ctx);

    witness.allow_public_burn(
        &mut ipx_treasury,
    );

    let sui_amount_in = 500;

    let quote_swap_fee_amount_initial = quote_swap_fee.calculate(sui_amount_in);

    let (_, coin_meme_out) = cp.pump(
        mint_for_testing<SUI>(sui_amount_in, &mut ctx),
        option::none(),
        0,
        &mut ctx,
    );

    let meme_coin_out_value = coin_meme_out.value();

    let amounts = cp.dump_amount(meme_coin_out_value);

    let meme_swap_fee_amount_out = meme_swap_fee.calculate(meme_coin_out_value);

    let fee_rate = burner.calculate(cp.quote_balance().value());

    let meme_burn_fee_value = fee_rate.calc_up(meme_coin_out_value - meme_swap_fee_amount_out);

    let amount_out = get_amount_out!(
        meme_coin_out_value - meme_swap_fee_amount_out - meme_burn_fee_value,
        cp.meme_balance().value(),
        cp.quote_balance().value() + virtual_liquidity,
    );

    let sui_amount_fee_out = quote_swap_fee.calculate(amount_out);

    let sui_coin_out = cp.dump(
        &mut ipx_treasury,
        coin_meme_out,
        option::none(),
        amounts[0],
        &mut ctx,
    );

    assert_eq(meme_burn_fee_value, amounts[2]);
    assert_eq(ipx_treasury.total_supply<Meme>(), meme_balance_value - meme_burn_fee_value);
    assert_eq(amount_out - sui_amount_fee_out, amounts[0]);

    assert_eq(
        cp.quote_balance().value(),
        sui_amount_in - amounts[3] - amounts[0] - quote_swap_fee_amount_initial,
    );
    assert_eq(
        cp.meme_balance().value(),
        meme_balance_value - meme_swap_fee_amount_out - meme_burn_fee_value - amounts[1],
    );
    assert_eq(amounts[1], meme_swap_fee_amount_out);
    assert_eq(amounts[3], sui_amount_fee_out);

    sui_coin_out.burn_for_testing();

    destroy(witness);
    destroy(ipx_treasury);
    destroy(cp);
}

#[test]
fun test_pump_amount() {
    let virtual_liquidity = 100;
    let target_sui_liquidity = 1100;
    let meme_balance_value = 5000;

    let quote_swap_fee = memez_fees::new_percentage_fee(
        30,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let meme_swap_fee = memez_fees::new_percentage_fee(
        50,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let cp = memez_constant_product::new<Meme, Quote>(
        virtual_liquidity,
        target_sui_liquidity,
        balance::create_for_testing<Meme>(meme_balance_value),
        meme_swap_fee,
        quote_swap_fee,
        bps::new(0),
        bps::new(0),
        BURN_TAX,
    );

    let amount_in = 250;

    let quote_swap_fee_amount = quote_swap_fee.calculate(amount_in);

    let amount_out = get_amount_out!(
        amount_in - quote_swap_fee_amount,
        virtual_liquidity,
        meme_balance_value,
    );

    let meme_swap_fee_amount_out = meme_swap_fee.calculate(amount_out);

    let amounts = cp.pump_amount(amount_in);

    assert_eq(amounts[0], amount_out - meme_swap_fee_amount_out);
    assert_eq(amounts[1], quote_swap_fee_amount);
    assert_eq(amounts[2], meme_swap_fee_amount_out);

    let amounts = cp.pump_amount(0);

    assert_eq(amounts[0], 0);
    assert_eq(amounts[1], 0);
    assert_eq(amounts[2], 0);

    destroy(cp);
}

#[test]
fun test_dump_amount() {
    let virtual_liquidity = 100;
    let target_sui_liquidity = 1100;
    let meme_balance_value = 5000;

    let quote_swap_fee = memez_fees::new_percentage_fee(
        30,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let meme_swap_fee = memez_fees::new_percentage_fee(
        50,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let burner = memez_burner::new(BURN_TAX, target_sui_liquidity);

    let mut cp = memez_constant_product::new<Meme, Quote>(
        virtual_liquidity,
        target_sui_liquidity,
        balance::create_for_testing<Meme>(meme_balance_value),
        meme_swap_fee,
        quote_swap_fee,
        bps::new(0),
        bps::new(0),
        BURN_TAX,
    );

    let amount_in = 1000;

    let meme_swap_fee_amount_out = meme_swap_fee.calculate(amount_in);

    let dynamic_burn_tax = burner.calculate(0);

    let meme_burn_fee_value = dynamic_burn_tax.calc_up(amount_in - meme_swap_fee_amount_out);

    let amount_out = get_amount_out!(
        amount_in - meme_swap_fee_amount_out - meme_burn_fee_value,
        meme_balance_value,
        virtual_liquidity,
    );

    let amounts = cp.dump_amount(amount_in);

    assert_eq(amounts[0], 0);
    assert_eq(amount_out != 0, true);
    assert_eq(amounts[1], meme_swap_fee_amount_out);
    assert_eq(amounts[3], 0);

    cp.quote_balance_mut().join(balance::create_for_testing<Quote>(600));

    let quote_balance = cp.quote_balance().value();

    let dynamic_burn_tax = burner.calculate(quote_balance);

    let meme_burn_fee_value = dynamic_burn_tax.calc_up(amount_in - meme_swap_fee_amount_out);

    let amount_out = get_amount_out!(
        amount_in - meme_swap_fee_amount_out - meme_burn_fee_value,
        meme_balance_value,
        virtual_liquidity + 600,
    );

    let quote_swap_fee_amount_out = quote_swap_fee.calculate(amount_out);

    let amounts = cp.dump_amount(amount_in);

    assert_eq(amounts[0], amount_out - quote_swap_fee_amount_out);
    assert_eq(amounts[0] != 0, true);
    assert_eq(amounts[1], meme_swap_fee_amount_out);
    assert_eq(amounts[2], meme_burn_fee_value);
    assert_eq(amounts[3], quote_swap_fee_amount_out);

    let amounts = cp.dump_amount(0);

    assert_eq(amounts[0], 0);
    assert_eq(amounts[1], 0);
    assert_eq(amounts[2], 0);
    assert_eq(amounts[3], 0);

    destroy(cp);
}

#[test]
fun test_dump_amount_no_fees() {
    let virtual_liquidity = 100;
    let target_sui_liquidity = 1100;
    let meme_balance_value = 5000;

    let swap_fee = memez_fees::new_percentage_fee(
        0,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let mut cp = memez_constant_product::new<Meme, Quote>(
        virtual_liquidity,
        target_sui_liquidity,
        balance::create_for_testing<Meme>(meme_balance_value),
        swap_fee,
        swap_fee,
        bps::new(0),
        bps::new(0),
        0,
    );

    let amount_in = 1000;

    let amount_out = get_amount_out!(amount_in, meme_balance_value, virtual_liquidity);

    let amounts = cp.dump_amount(amount_in);

    assert_eq(amounts[0], 0);
    assert_eq(amount_out != 0, true);
    assert_eq(amounts[1], 0);
    assert_eq(amounts[2], 0);
    assert_eq(amounts[3], 0);

    cp.quote_balance_mut().join(balance::create_for_testing<Quote>(600));

    let amount_out = get_amount_out!(amount_in, meme_balance_value, virtual_liquidity + 600);

    let amounts = cp.dump_amount(amount_in);

    assert_eq(amounts[0], amount_out);
    assert_eq(amounts[0] != 0, true);
    assert_eq(amounts[1], 0);
    assert_eq(amounts[2], 0);
    assert_eq(amounts[3], 0);

    let amounts = cp.dump_amount(0);

    assert_eq(amounts[0], 0);
    assert_eq(amounts[1], 0);
    assert_eq(amounts[2], 0);
    assert_eq(amounts[3], 0);

    destroy(cp);
}

#[test]
fun test_pump_with_referrer() {
    let mut scenario = ts::begin(REFERRER_ADDRESS);

    let virtual_liquidity = 100;
    let target_sui_liquidity = 5000;
    let meme_balance_value = 5000;

    let quote_swap_fee = memez_fees::new_percentage_fee(
        30,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let meme_swap_fee = memez_fees::new_percentage_fee(
        20,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let quote_discount = bps::new(10);

    let meme_discount = bps::new(5);

    let mut cp = memez_constant_product::new(
        virtual_liquidity,
        target_sui_liquidity,
        balance::create_for_testing<Meme>(meme_balance_value),
        meme_swap_fee,
        quote_swap_fee,
        meme_discount,
        quote_discount,
        0,
    );

    let amount_in = 2_000;

    let quote_swap_fee_amount = quote_swap_fee.calculate(amount_in);

    let amount_out = get_amount_out!(
        amount_in - quote_swap_fee_amount,
        virtual_liquidity,
        meme_balance_value,
    );

    let amounts = cp.pump_amount(amount_in);

    let sui_coin = mint_for_testing<SUI>(amount_in, scenario.ctx());

    let quote_referrer_fee_value = quote_discount.calc_up(amount_in);

    let (can_migrate, coin_meme_out) = cp.pump(
        sui_coin,
        option::some(REFERRER_ADDRESS),
        0,
        scenario.ctx(),
    );

    let coin_meme_out_value = coin_meme_out.value();

    let meme_referrer_fee_value = meme_discount.calc_up(coin_meme_out_value);

    let meme_swap_fee_amount_out = meme_swap_fee.calculate_with_discount(meme_discount, amount_out);

    assert_eq(can_migrate, false);
    assert_eq(coin_meme_out.value(), amounts[0]);
    assert_eq(amounts[1], quote_swap_fee.calculate(amount_in));
    assert_eq(
        coin_meme_out.burn_for_testing(),
        amount_out - meme_discount.calc_up(amount_out) - meme_swap_fee_amount_out,
    );
    assert_eq(cp.quote_balance().value(), amount_in - quote_swap_fee_amount);
    assert_eq(cp.virtual_liquidity(), virtual_liquidity);
    assert_eq(cp.meme_balance().value(), meme_balance_value - amount_out);
    assert_eq(meme_swap_fee_amount_out + meme_discount.calc_up(amount_out), amounts[2]);

    scenario.next_epoch(REFERRER_ADDRESS);

    let meme_referrer_coin = scenario.take_from_sender<Coin<Meme>>();
    let quote_referrer_coin = scenario.take_from_sender<Coin<SUI>>();

    assert_eq(meme_referrer_coin.burn_for_testing(), meme_referrer_fee_value);
    assert_eq(quote_referrer_coin.burn_for_testing(), quote_referrer_fee_value);

    destroy(cp);

    scenario.end();
}

#[test]
fun test_dump_with_referrer() {
    let mut scenario = ts::begin(REFERRER_ADDRESS);

    let virtual_liquidity = 100;
    let target_sui_liquidity = 5000;
    let meme_balance_value = 5000;

    let quote_swap_fee = memez_fees::new_percentage_fee(
        30,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let meme_swap_fee = memez_fees::new_percentage_fee(
        20,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let quote_discount = bps::new(10);

    let meme_discount = bps::new(5);

    let mut meme_treasury_cap = coin::create_treasury_cap_for_testing<Meme>(scenario.ctx());

    let mut cp = memez_constant_product::new(
        virtual_liquidity,
        target_sui_liquidity,
        meme_treasury_cap.mint(meme_balance_value, scenario.ctx()).into_balance(),
        meme_swap_fee,
        quote_swap_fee,
        meme_discount,
        quote_discount,
        0,
    );

    let (mut ipx_treasury, mut witness) = ipx_coin_standard::new(meme_treasury_cap, scenario.ctx());

    witness.allow_public_burn(
        &mut ipx_treasury,
    );

    let sui_amount_in = 2_000;

    let quote_swap_fee_amount_initial =
        quote_swap_fee.calculate_with_discount(quote_discount, sui_amount_in) + quote_discount.calc_up(sui_amount_in);

    let (_, coin_meme_out) = cp.pump(
        mint_for_testing<SUI>(sui_amount_in, scenario.ctx()),
        option::some(REFERRER_ADDRESS),
        0,
        scenario.ctx(),
    );

    let meme_coin_value = coin_meme_out.value();

    let amounts = cp.dump_amount(meme_coin_value);

    let meme_referrer_fee_value = meme_discount.calc_up(meme_coin_value);

    let meme_swap_fee_amount_out =
        meme_swap_fee.calculate_with_discount(meme_discount, meme_coin_value) + meme_referrer_fee_value;

    let amount_out = get_amount_out!(
        meme_coin_value - meme_swap_fee_amount_out,
        cp.meme_balance().value(),
        cp.quote_balance().value() + virtual_liquidity,
    );

    let quote_referrer_fee_value = quote_discount.calc_up(amount_out);

    let sui_swap_fee_amount_out =
        quote_swap_fee.calculate_with_discount(quote_discount, amount_out) + quote_referrer_fee_value;

    let sui_coin_out = cp.dump(
        &mut ipx_treasury,
        coin_meme_out,
        option::some(REFERRER_ADDRESS),
        amounts[0],
        scenario.ctx(),
    );

    assert_eq(0, amounts[2]);
    assert_eq(ipx_treasury.total_supply<Meme>(), meme_balance_value);
    assert_eq(amount_out - sui_swap_fee_amount_out, amounts[0]);

    assert_eq(
        cp.quote_balance().value(),
        sui_amount_in - amounts[3] - amounts[0] - quote_swap_fee_amount_initial,
    );
    assert_eq(
        cp.meme_balance().value(),
        meme_balance_value - meme_swap_fee_amount_out - amounts[1],
    );
    assert_eq(amounts[1], meme_swap_fee_amount_out);
    assert_eq(amounts[3], sui_swap_fee_amount_out);

    assert_eq(sui_coin_out.burn_for_testing(), amount_out - sui_swap_fee_amount_out);

    scenario.next_epoch(REFERRER_ADDRESS);

    let meme_referrer_coin = scenario.take_from_sender<Coin<Meme>>();
    let quote_referrer_coin = scenario.take_from_sender<Coin<SUI>>();

    assert_eq(meme_referrer_coin.burn_for_testing(), meme_referrer_fee_value);
    assert_eq(quote_referrer_coin.burn_for_testing(), quote_referrer_fee_value);

    destroy(witness);
    destroy(ipx_treasury);
    destroy(cp);

    scenario.end();
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EZeroCoin,
        location = memez_fun::memez_constant_product,
    ),
]
fun test_pump_zero_coin() {
    let mut ctx = tx_context::dummy();

    let virtual_liquidity = 100;
    let target_sui_liquidity = 1100;
    let meme_balance_value = 5000;

    let swap_fee = memez_fees::new_percentage_fee(
        0,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let mut cp = memez_constant_product::new<Meme, Quote>(
        virtual_liquidity,
        target_sui_liquidity,
        balance::create_for_testing<Meme>(meme_balance_value),
        swap_fee,
        swap_fee,
        bps::new(0),
        bps::new(0),
        0,
    );

    let (_can_migrate, _coin_meme_out) = cp.pump(
        coin::zero(&mut ctx),
        option::none(),
        0,
        &mut ctx,
    );

    abort
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::ESlippage,
        location = memez_fun::memez_constant_product,
    ),
]
fun test_pump_slippage() {
    let mut ctx = tx_context::dummy();

    let virtual_liquidity = 100;
    let target_sui_liquidity = 1100;
    let meme_balance_value = 5000;

    let swap_fee = memez_fees::new_percentage_fee(
        0,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let mut cp = memez_constant_product::new<Meme, SUI>(
        virtual_liquidity,
        target_sui_liquidity,
        balance::create_for_testing<Meme>(meme_balance_value),
        swap_fee,
        swap_fee,
        bps::new(0),
        bps::new(0),
        0,
    );

    let amount_in = 250;

    let expected_amount_out = cp.pump_amount(amount_in);

    let (_can_migrate, _coin_meme_out) = cp.pump(
        mint_for_testing<SUI>(amount_in, &mut ctx),
        option::none(),
        expected_amount_out[0] + 1,
        &mut ctx,
    );

    abort
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::EZeroCoin,
        location = memez_fun::memez_constant_product,
    ),
]
fun test_dump_zero_coin() {
    let mut ctx = tx_context::dummy();

    let virtual_liquidity = 100;
    let target_sui_liquidity = 1100;
    let meme_balance_value = 5000;
    let swap_fee = memez_fees::new_percentage_fee(
        0,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let meme_treasury_cap = coin::create_treasury_cap_for_testing<Meme>(&mut ctx);

    let (mut ipx_treasury, witness) = ipx_coin_standard::new(meme_treasury_cap, &mut ctx);

    destroy(witness);

    let mut cp = memez_constant_product::new<Meme, SUI>(
        virtual_liquidity,
        target_sui_liquidity,
        balance::create_for_testing<Meme>(meme_balance_value),
        swap_fee,
        swap_fee,
        bps::new(0),
        bps::new(0),
        0,
    );

    cp
        .dump(
            &mut ipx_treasury,
            coin::zero(&mut ctx),
            option::none(),
            0,
            &mut ctx,
        )
        .burn_for_testing();

    abort
}

#[
    test,
    expected_failure(
        abort_code = memez_errors::ESlippage,
        location = memez_fun::memez_constant_product,
    ),
]
fun test_dump_slippage() {
    let mut ctx = tx_context::dummy();

    let virtual_liquidity = 100;
    let target_sui_liquidity = 1100;
    let meme_balance_value = 5000;
    let swap_fee = memez_fees::new_percentage_fee(
        0,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let mut meme_treasury_cap = coin::create_treasury_cap_for_testing<Meme>(&mut ctx);

    let mut cp = memez_constant_product::new(
        virtual_liquidity,
        target_sui_liquidity,
        meme_treasury_cap.mint(meme_balance_value, &mut ctx).into_balance(),
        swap_fee,
        swap_fee,
        bps::new(0),
        bps::new(0),
        0,
    );

    let (mut ipx_treasury, mut witness) = ipx_coin_standard::new(meme_treasury_cap, &mut ctx);

    witness.allow_public_burn(
        &mut ipx_treasury,
    );

    let sui_amount_in = 500;

    let (_, coin_meme_out) = cp.pump(
        mint_for_testing<SUI>(sui_amount_in, &mut ctx),
        option::none(),
        0,
        &mut ctx,
    );

    let meme_coin_out_value = coin_meme_out.value();

    let amounts = cp.dump_amount(meme_coin_out_value);

    cp
        .dump(
            &mut ipx_treasury,
            coin_meme_out,
            option::none(),
            amounts[0] + 1,
            &mut ctx,
        )
        .burn_for_testing();

    destroy(witness);
    destroy(ipx_treasury);
    destroy(cp);
}
