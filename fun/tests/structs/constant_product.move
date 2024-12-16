#[test_only]
module memez_fun::memez_constant_product_tests;

use constant_product::constant_product::get_amount_out;
use ipx_coin_standard::ipx_coin_standard;
use memez_fun::{
    memez_burner,
    memez_constant_product,
    memez_distributor,
    memez_errors,
    memez_fees,
    memez_utils
};
use sui::{balance, coin::{Self, mint_for_testing}, sui::SUI, test_utils::{assert_eq, destroy}};

public struct Meme has drop ()

const BURN_TAX: u64 = 2_000;

const BPS_MAX: u64 = 10_000;

#[test]
fun test_new() {
    let virtual_liquidity = 100;
    let target_sui_liquidity = 1100;
    let meme_balance_value = 5000;

    let cp = memez_constant_product::new(
        virtual_liquidity,
        target_sui_liquidity,
        balance::create_for_testing<Meme>(meme_balance_value),
        memez_fees::new_percentage_fee(
            30,
            memez_distributor::new(
                vector[@0x0],
                vector[BPS_MAX],
            ),
        ),
        BURN_TAX,
    );

    assert_eq(cp.virtual_liquidity(), virtual_liquidity);
    assert_eq(cp.target_sui_liquidity(), target_sui_liquidity);
    assert_eq(cp.meme_balance().value(), meme_balance_value);
    assert_eq(cp.burner().fee().value(), BURN_TAX);
    assert_eq(cp.burner().start_liquidity(), virtual_liquidity);
    assert_eq(cp.burner().target_liquidity(), target_sui_liquidity);

    destroy(cp);
}

#[test]
fun test_set_memez_fun() {
    let mut cp = memez_constant_product::new(
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
        BURN_TAX,
    );

    let amount_in = 250;

    let amount_out = get_amount_out(
        amount_in,
        virtual_liquidity,
        meme_balance_value,
    );

    let amounts = cp.pump_amount(amount_in, 0);

    let (can_migrate, coin_meme_out) = cp.pump(
        mint_for_testing<SUI>(amount_in, &mut ctx),
        0,
        &mut ctx,
    );

    assert_eq(can_migrate, false);
    assert_eq(coin_meme_out.value(), amounts[0]);
    assert_eq(amounts[1], swap_fee.calculate(amount_in));
    assert_eq(coin_meme_out.burn_for_testing(), amount_out);
    assert_eq(cp.sui_balance().value(), amount_in);
    assert_eq(cp.virtual_liquidity(), virtual_liquidity);
    assert_eq(cp.meme_balance().value(), meme_balance_value - amount_out);

    let meme_balance_value = cp.meme_balance().value();

    let new_sui_balance = amount_in;

    let amount_in = target_sui_liquidity - amount_in;

    let amount_out = get_amount_out(
        amount_in,
        virtual_liquidity + new_sui_balance,
        meme_balance_value,
    );

    let amounts = cp.pump_amount(amount_in, 0);

    let (can_migrate, coin_meme_out) = cp.pump(
        mint_for_testing<SUI>(amount_in, &mut ctx),
        0,
        &mut ctx,
    );

    assert_eq(can_migrate, true);
    assert_eq(coin_meme_out.value(), amounts[0]);
    assert_eq(amounts[1], swap_fee.calculate(amount_in));
    assert_eq(coin_meme_out.burn_for_testing(), amount_out);
    assert_eq(cp.sui_balance().value(), amount_in + new_sui_balance);
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

    let swap_fee = memez_fees::new_percentage_fee(
        30,
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
        BURN_TAX,
    );

    let amount_in = 250;

    let tax_fee = swap_fee.calculate(amount_in);

    let amount_out = get_amount_out(
        amount_in - tax_fee,
        virtual_liquidity,
        meme_balance_value,
    );

    let amounts = cp.pump_amount(amount_in, 0);

    let (can_migrate, coin_meme_out) = cp.pump(
        mint_for_testing<SUI>(amount_in, &mut ctx),
        0,
        &mut ctx,
    );

    assert_eq(can_migrate, false);
    assert_eq(coin_meme_out.value(), amounts[0]);
    assert_eq(amounts[1], swap_fee.calculate(amount_in));
    assert_eq(coin_meme_out.burn_for_testing(), amount_out);
    assert_eq(cp.sui_balance().value(), amount_in - tax_fee);
    assert_eq(cp.virtual_liquidity(), virtual_liquidity);
    assert_eq(cp.meme_balance().value(), meme_balance_value - amount_out);

    let meme_balance_value = cp.meme_balance().value();

    let mut new_sui_balance = amount_in - tax_fee;

    let amount_in = target_sui_liquidity - amount_in;

    let tax_fee = swap_fee.calculate(amount_in);

    let amount_out = get_amount_out(
        amount_in - tax_fee,
        virtual_liquidity + new_sui_balance,
        meme_balance_value,
    );

    let amounts = cp.pump_amount(amount_in, 0);

    let (can_migrate, coin_meme_out) = cp.pump(
        mint_for_testing<SUI>(amount_in, &mut ctx),
        0,
        &mut ctx,
    );

    assert_eq(can_migrate, false);
    assert_eq(coin_meme_out.value(), amounts[0]);
    assert_eq(amounts[1], swap_fee.calculate(amount_in));
    assert_eq(coin_meme_out.burn_for_testing(), amount_out);
    assert_eq(cp.sui_balance().value(), amount_in + new_sui_balance - tax_fee);
    assert_eq(cp.virtual_liquidity(), virtual_liquidity);
    assert_eq(cp.meme_balance().value(), meme_balance_value - amount_out);

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
        0,
    );

    let (mut ipx_treasury, mut witness) = ipx_coin_standard::new(meme_treasury_cap, &mut ctx);

    witness.allow_public_burn(
        &mut ipx_treasury,
    );

    let sui_amount_in = 500;

    let (_, coin_meme_out) = cp.pump(
        mint_for_testing<SUI>(sui_amount_in, &mut ctx),
        0,
        &mut ctx,
    );

    let meme_coin_out_value = coin_meme_out.value();

    let amounts = cp.dump_amount(meme_coin_out_value, 0);

    let amount_out = get_amount_out(
        meme_coin_out_value,
        cp.meme_balance().value(),
        cp.sui_balance().value() + virtual_liquidity,
    );

    let sui_coin_out = cp.dump(
        &mut ipx_treasury,
        coin_meme_out,
        amounts[0],
        &mut ctx,
    );

    assert_eq(0, amounts[3]);
    assert_eq(ipx_treasury.total_supply<Meme>(), meme_balance_value);
    assert_eq(amount_out, amounts[0]);

    assert_eq(cp.sui_balance().value(), sui_amount_in - amounts[0]);
    assert_eq(cp.meme_balance().value(), meme_balance_value);
    assert_eq(amounts[2], 0);
    assert_eq(amounts[1], amounts[0]);

    sui_coin_out.burn_for_testing();

    let amount_out = get_amount_out(
        meme_coin_out_value,
        cp.meme_balance().value(),
        cp.sui_balance().value() + virtual_liquidity,
    );

    cp
        .dump(
            &mut ipx_treasury,
            coin::mint_for_testing<Meme>(meme_coin_out_value, &mut ctx),
            0,
            &mut ctx,
        )
        .burn_for_testing();

    assert_eq(amount_out != 0, true);

    let amounts = cp.dump_amount(meme_coin_out_value, 0);

    let amount_out = get_amount_out(
        meme_coin_out_value,
        cp.meme_balance().value(),
        cp.sui_balance().value() + virtual_liquidity,
    );

    assert_eq(amounts[0], 0);
    assert_eq(amounts[1], amount_out);
    assert_eq(amount_out != 0, true);

    cp
        .dump(
            &mut ipx_treasury,
            coin::mint_for_testing<Meme>(meme_coin_out_value, &mut ctx),
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

    let swap_fee = memez_fees::new_percentage_fee(
        30,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let burner = memez_burner::new(vector[BURN_TAX, virtual_liquidity, target_sui_liquidity]);

    let mut meme_treasury_cap = coin::create_treasury_cap_for_testing<Meme>(&mut ctx);

    let mut cp = memez_constant_product::new(
        virtual_liquidity,
        target_sui_liquidity,
        meme_treasury_cap.mint(meme_balance_value, &mut ctx).into_balance(),
        swap_fee,
        BURN_TAX,
    );

    let (mut ipx_treasury, mut witness) = ipx_coin_standard::new(meme_treasury_cap, &mut ctx);

    witness.allow_public_burn(
        &mut ipx_treasury,
    );

    let sui_amount_in = 500;

    let sui_swap_fee_amount = swap_fee.calculate(sui_amount_in);

    let (_, coin_meme_out) = cp.pump(
        mint_for_testing<SUI>(sui_amount_in, &mut ctx),
        0,
        &mut ctx,
    );

    let meme_coin_out_value = coin_meme_out.value();

    let amounts = cp.dump_amount(meme_coin_out_value, 0);

    let swap_fee_value = swap_fee.calculate(meme_coin_out_value);

    let pre_tax_amount_out = get_amount_out(
        meme_coin_out_value - swap_fee_value,
        cp.meme_balance().value(),
        cp.sui_balance().value() + virtual_liquidity,
    );

    let fee_rate = burner.calculate(
        cp.sui_balance().value() + virtual_liquidity - pre_tax_amount_out,
    );

    let meme_burn_fee_value = fee_rate.calc_up(meme_coin_out_value - swap_fee_value);

    let amount_out = get_amount_out(
        meme_coin_out_value - swap_fee_value - meme_burn_fee_value,
        cp.meme_balance().value(),
        cp.sui_balance().value() + virtual_liquidity,
    );

    let sui_coin_out = cp.dump(
        &mut ipx_treasury,
        coin_meme_out,
        amounts[0],
        &mut ctx,
    );

    assert_eq(meme_burn_fee_value, amounts[3]);
    assert_eq(ipx_treasury.total_supply<Meme>(), meme_balance_value - meme_burn_fee_value);
    assert_eq(amount_out, amounts[0]);

    assert_eq(cp.sui_balance().value(), sui_amount_in - amounts[0] - sui_swap_fee_amount);
    assert_eq(cp.meme_balance().value(), meme_balance_value - swap_fee_value - meme_burn_fee_value);
    assert_eq(amounts[2], swap_fee_value);
    assert_eq(amounts[1], amounts[0]);

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

    let swap_fee = memez_fees::new_percentage_fee(
        30,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let cp = memez_constant_product::new(
        virtual_liquidity,
        target_sui_liquidity,
        balance::create_for_testing<Meme>(meme_balance_value),
        swap_fee,
        BURN_TAX,
    );

    let amount_in = 250;

    let swap_fee_amount = swap_fee.calculate(amount_in);

    let amount_out = get_amount_out(
        amount_in - swap_fee_amount,
        virtual_liquidity,
        meme_balance_value + 1200,
    );

    let amounts = cp.pump_amount(amount_in, 1200);

    assert_eq(amounts[0], amount_out);
    assert_eq(amounts[1], swap_fee_amount);

    let amounts = cp.pump_amount(0, 1200);

    assert_eq(amounts[0], 0);
    assert_eq(amounts[1], 0);

    destroy(cp);
}

#[test]
fun test_dump_amount() {
    let virtual_liquidity = 100;
    let target_sui_liquidity = 1100;
    let meme_balance_value = 5000;

    let swap_fee = memez_fees::new_percentage_fee(
        30,
        memez_distributor::new(
            vector[@0x0],
            vector[BPS_MAX],
        ),
    );

    let burner = memez_burner::new(vector[BURN_TAX, virtual_liquidity, target_sui_liquidity]);

    let mut cp = memez_constant_product::new(
        virtual_liquidity,
        target_sui_liquidity,
        balance::create_for_testing<Meme>(meme_balance_value),
        swap_fee,
        BURN_TAX,
    );

    let amount_in = 1000;

    let swap_fee_amount = swap_fee.calculate(amount_in);

    let amount_out = get_amount_out(
        amount_in - swap_fee_amount,
        meme_balance_value + 1200,
        virtual_liquidity,
    );

    let dynamic_burn_tax = burner.calculate(virtual_liquidity - amount_out);

    let meme_burn_fee_value = dynamic_burn_tax.calc_up(amount_in - swap_fee_amount);

    let amount_out = get_amount_out(
        amount_in - swap_fee_amount - meme_burn_fee_value,
        meme_balance_value + 1200,
        virtual_liquidity,
    );

    let amounts = cp.dump_amount(amount_in, 1200);

    assert_eq(amounts[0], 0);
    assert_eq(amounts[1], amount_out);
    assert_eq(amounts[1] != 0, true);
    assert_eq(amounts[2], swap_fee_amount);
    assert_eq(amounts[3], meme_burn_fee_value);

    cp.sui_balance_mut().join(balance::create_for_testing<SUI>(600));

    let amount_out = get_amount_out(
        amount_in - swap_fee_amount,
        meme_balance_value + 1200,
        virtual_liquidity + 600,
    );

    let dynamic_burn_tax = burner.calculate(virtual_liquidity + 600 - amount_out);

    let meme_burn_fee_value = dynamic_burn_tax.calc_up(amount_in - swap_fee_amount);

    let amount_out = get_amount_out(
        amount_in - swap_fee_amount - meme_burn_fee_value,
        meme_balance_value + 1200,
        virtual_liquidity + 600,
    );

    let amounts = cp.dump_amount(amount_in, 1200);

    assert_eq(amounts[0], amount_out);
    assert_eq(amounts[0] != 0, true);
    assert_eq(amounts[1], amount_out);
    assert_eq(amounts[2], swap_fee_amount);
    assert_eq(amounts[3], meme_burn_fee_value);

    let amounts = cp.dump_amount(0, 1200);

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

    let mut cp = memez_constant_product::new(
        virtual_liquidity,
        target_sui_liquidity,
        balance::create_for_testing<Meme>(meme_balance_value),
        swap_fee,
        0,
    );

    let amount_in = 1000;

    let amount_out = get_amount_out(
        amount_in,
        meme_balance_value + 1200,
        virtual_liquidity,
    );

    let amounts = cp.dump_amount(amount_in, 1200);

    assert_eq(amounts[0], 0);
    assert_eq(amounts[1], amount_out);
    assert_eq(amounts[1] != 0, true);
    assert_eq(amounts[2], 0);
    assert_eq(amounts[3], 0);

    cp.sui_balance_mut().join(balance::create_for_testing<SUI>(600));

    let amount_out = get_amount_out(
        amount_in,
        meme_balance_value + 1200,
        virtual_liquidity + 600,
    );

    let amounts = cp.dump_amount(amount_in, 1200);

    assert_eq(amounts[0], amount_out);
    assert_eq(amounts[0] != 0, true);
    assert_eq(amounts[1], amount_out);
    assert_eq(amounts[2], 0);
    assert_eq(amounts[3], 0);

    let amounts = cp.dump_amount(0, 1200);

    assert_eq(amounts[0], 0);
    assert_eq(amounts[1], 0);
    assert_eq(amounts[2], 0);
    assert_eq(amounts[3], 0);

    destroy(cp);
}

#[test, expected_failure(abort_code = memez_errors::EZeroCoin, location = memez_utils)]
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

    let mut cp = memez_constant_product::new(
        virtual_liquidity,
        target_sui_liquidity,
        balance::create_for_testing<Meme>(meme_balance_value),
        swap_fee,
        0,
    );

    let (_can_migrate, _coin_meme_out) = cp.pump(
        coin::zero(&mut ctx),
        0,
        &mut ctx,
    );

    abort
}

#[test, expected_failure(abort_code = memez_errors::ESlippage, location = memez_utils)]
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

    let mut cp = memez_constant_product::new(
        virtual_liquidity,
        target_sui_liquidity,
        balance::create_for_testing<Meme>(meme_balance_value),
        swap_fee,
        0,
    );

    let amount_in = 250;

    let expected_amount_out = cp.pump_amount(amount_in, 0);

    let (_can_migrate, _coin_meme_out) = cp.pump(
        mint_for_testing<SUI>(amount_in, &mut ctx),
        expected_amount_out[0] + 1,
        &mut ctx,
    );

    abort
}

#[test, expected_failure(abort_code = memez_errors::EZeroCoin, location = memez_utils)]
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

    let mut cp = memez_constant_product::new(
        virtual_liquidity,
        target_sui_liquidity,
        balance::create_for_testing<Meme>(meme_balance_value),
        swap_fee,
        0,
    );

    cp
        .dump(
            &mut ipx_treasury,
            coin::zero(&mut ctx),
            0,
            &mut ctx,
        )
        .burn_for_testing();

    abort
}

#[test, expected_failure(abort_code = memez_errors::ESlippage, location = memez_utils)]
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
        0,
    );

    let (mut ipx_treasury, mut witness) = ipx_coin_standard::new(meme_treasury_cap, &mut ctx);

    witness.allow_public_burn(
        &mut ipx_treasury,
    );

    let sui_amount_in = 500;

    let (_, coin_meme_out) = cp.pump(
        mint_for_testing<SUI>(sui_amount_in, &mut ctx),
        0,
        &mut ctx,
    );

    let meme_coin_out_value = coin_meme_out.value();

    let amounts = cp.dump_amount(meme_coin_out_value, 0);

    cp
        .dump(
            &mut ipx_treasury,
            coin_meme_out,
            amounts[0] + 1,
            &mut ctx,
        )
        .burn_for_testing();

    destroy(witness);
    destroy(ipx_treasury);
    destroy(cp);
}
