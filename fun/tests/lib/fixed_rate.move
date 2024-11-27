#[test_only]
module memez_fun::memez_fixed_rate_tests;

use memez_fun::{memez_errors, memez_fixed_rate, memez_utils};
use sui::{balance, coin::mint_for_testing, sui::SUI, test_utils::{assert_eq, destroy}};

public struct Meme()

#[test]
fun test_new() {
    let sui_raise_amount = 1000;
    let meme_balance_value = 5000;

    let meme_balance = balance::create_for_testing<Meme>(meme_balance_value);

    let mut fixed_rate = memez_fixed_rate::new(
        sui_raise_amount,
        meme_balance,
    );

    assert_eq(fixed_rate.sui_raise_amount(), sui_raise_amount);
    assert_eq(fixed_rate.memez_fun(), @0x0);
    assert_eq(fixed_rate.meme_sale_amount(), meme_balance_value);
    assert_eq(fixed_rate.meme_balance().value(), meme_balance_value);
    assert_eq(fixed_rate.sui_balance().value(), 0);

    fixed_rate.set_memez_fun(@0x1);

    assert_eq(fixed_rate.memez_fun(), @0x1);

    destroy(fixed_rate);
}

#[test]
fun test_pump() {
    let mut ctx = tx_context::dummy();

    let sui_raise_amount = 1000;
    let meme_balance_value = 5000;

    let meme_balance = balance::create_for_testing<Meme>(meme_balance_value);

    let mut fixed_rate = memez_fixed_rate::new(
        sui_raise_amount,
        meme_balance,
    );

    let (excess_amount, min_amount_out) = fixed_rate.pump_amount(200);

    let (can_migrate, excess_sui_coin, meme_coin_out) = fixed_rate.pump(
        mint_for_testing<SUI>(200, &mut ctx),
        min_amount_out,
        &mut ctx,
    );

    assert_eq(can_migrate, false);
    assert_eq(excess_amount, 0);
    assert_eq(excess_sui_coin.burn_for_testing(), 0);
    assert_eq(meme_coin_out.burn_for_testing(), 1000);

    let (excess_amount, min_amount_out) = fixed_rate.pump_amount(400);

    let (can_migrate, excess_sui_coin, meme_coin_out) = fixed_rate.pump(
        mint_for_testing<SUI>(400, &mut ctx),
        min_amount_out,
        &mut ctx,
    );

    assert_eq(can_migrate, false);
    assert_eq(excess_amount, 0);
    assert_eq(excess_sui_coin.burn_for_testing(), 0);
    assert_eq(meme_coin_out.burn_for_testing(), 2000);

    let (excess_amount, min_amount_out) = fixed_rate.pump_amount(500);

    let (can_migrate, excess_sui_coin, meme_coin_out) = fixed_rate.pump(
        mint_for_testing<SUI>(500, &mut ctx),
        min_amount_out,
        &mut ctx,
    );

    assert_eq(can_migrate, true);
    assert_eq(excess_amount, 100);
    assert_eq(excess_sui_coin.burn_for_testing(), 100);
    assert_eq(meme_coin_out.burn_for_testing(), 2000);

    let (excess_amount, min_amount_out) = fixed_rate.pump_amount(500);

    let (can_migrate, excess_sui_coin, meme_coin_out) = fixed_rate.pump(
        mint_for_testing<SUI>(500, &mut ctx),
        min_amount_out,
        &mut ctx,
    );

    assert_eq(can_migrate, true);
    assert_eq(excess_amount, 500);
    assert_eq(excess_sui_coin.burn_for_testing(), 500);
    assert_eq(meme_coin_out.burn_for_testing(), 0);

    destroy(fixed_rate);
}

#[test]
fun test_dump() {
    let mut ctx = tx_context::dummy();

    let sui_raise_amount = 1000;
    let meme_balance_value = 5000;

    let meme_balance = balance::create_for_testing<Meme>(meme_balance_value);

    let mut fixed_rate = memez_fixed_rate::new(
        sui_raise_amount,
        meme_balance,
    );

    let (_, excess_sui_coin, meme_coin_out) = fixed_rate.pump(
        mint_for_testing<SUI>(1000, &mut ctx),
        0,
        &mut ctx,
    );

    excess_sui_coin.burn_for_testing();
    meme_coin_out.burn_for_testing();

    let min_amount_out = fixed_rate.dump_amount(1000);

    let sui_coin_out = fixed_rate.dump(
        mint_for_testing<Meme>(1000, &mut ctx),
        min_amount_out,
        &mut ctx,
    );

    assert_eq(sui_coin_out.burn_for_testing(), 200);

    let min_amount_out = fixed_rate.dump_amount(1000);

    let sui_coin_out = fixed_rate.dump(
        mint_for_testing<Meme>(1000, &mut ctx),
        min_amount_out,
        &mut ctx,
    );

    assert_eq(sui_coin_out.burn_for_testing(), 200);

    let min_amount_out = fixed_rate.dump_amount(2000);

    let sui_coin_out = fixed_rate.dump(
        mint_for_testing<Meme>(2000, &mut ctx),
        min_amount_out,
        &mut ctx,
    );

    assert_eq(sui_coin_out.burn_for_testing(), 400);

    let min_amount_out = fixed_rate.dump_amount(1000);

    let sui_coin_out = fixed_rate.dump(
        mint_for_testing<Meme>(1000, &mut ctx),
        min_amount_out,
        &mut ctx,
    );

    assert_eq(sui_coin_out.burn_for_testing(), 200);

    let min_amount_out = fixed_rate.dump_amount(2000);

    let sui_coin_out = fixed_rate.dump(
        mint_for_testing<Meme>(1000, &mut ctx),
        min_amount_out,
        &mut ctx,
    );

    assert_eq(min_amount_out, 0);
    assert_eq(sui_coin_out.burn_for_testing(), 0);

    destroy(fixed_rate);
}

#[test, expected_failure(abort_code = memez_errors::EZeroCoin, location = memez_utils)]
fun test_pump_zero_coin() {
    let mut ctx = tx_context::dummy();

    let sui_raise_amount = 1000;
    let meme_balance_value = 5000;

    let meme_balance = balance::create_for_testing<Meme>(meme_balance_value);

    let mut fixed_rate = memez_fixed_rate::new(
        sui_raise_amount,
        meme_balance,
    );

    let (_, excess_sui_coin, meme_coin_out) = fixed_rate.pump(
        mint_for_testing<SUI>(0, &mut ctx),
        0,
        &mut ctx,
    );

    meme_coin_out.burn_for_testing();
    excess_sui_coin.burn_for_testing();

    destroy(fixed_rate);
}

#[test, expected_failure(abort_code = memez_errors::ESlippage, location = memez_utils)]
fun test_pump_slippage() {
    let mut ctx = tx_context::dummy();

    let sui_raise_amount = 1000;
    let meme_balance_value = 5000;

    let meme_balance = balance::create_for_testing<Meme>(meme_balance_value);

    let mut fixed_rate = memez_fixed_rate::new(
        sui_raise_amount,
        meme_balance,
    );

    let (_, min_amount_out) = fixed_rate.pump_amount(400);

    let (_, excess_sui_coin, meme_coin_out) = fixed_rate.pump(
        mint_for_testing<SUI>(400, &mut ctx),
        min_amount_out + 1,
        &mut ctx,
    );

    meme_coin_out.burn_for_testing();
    excess_sui_coin.burn_for_testing();

    destroy(fixed_rate);
}

#[test, expected_failure(abort_code = memez_errors::EZeroCoin, location = memez_utils)]
fun test_dump_zero_coin() {
    let mut ctx = tx_context::dummy();

    let sui_raise_amount = 1000;
    let meme_balance_value = 5000;

    let meme_balance = balance::create_for_testing<Meme>(meme_balance_value);

    let mut fixed_rate = memez_fixed_rate::new(
        sui_raise_amount,
        meme_balance,
    );

    let (_, excess_sui_coin, meme_coin_out) = fixed_rate.pump(
        mint_for_testing<SUI>(1000, &mut ctx),
        0,
        &mut ctx,
    );

    excess_sui_coin.burn_for_testing();
    meme_coin_out.burn_for_testing();

    let min_amount_out = fixed_rate.dump_amount(1000);

    fixed_rate.dump(
        mint_for_testing<Meme>(0, &mut ctx),
        min_amount_out + 1,
        &mut ctx,
    ).burn_for_testing();

    abort
}

#[test, expected_failure(abort_code = memez_errors::ESlippage, location = memez_utils)]
fun test_dump_slippage() {
    let mut ctx = tx_context::dummy();

    let sui_raise_amount = 1000;
    let meme_balance_value = 5000;

    let meme_balance = balance::create_for_testing<Meme>(meme_balance_value);

    let mut fixed_rate = memez_fixed_rate::new(
        sui_raise_amount,
        meme_balance,
    );

    let (_, excess_sui_coin, meme_coin_out) = fixed_rate.pump(
        mint_for_testing<SUI>(1000, &mut ctx),
        0,
        &mut ctx,
    );

    excess_sui_coin.burn_for_testing();
    meme_coin_out.burn_for_testing();

    let min_amount_out = fixed_rate.dump_amount(1000);

    fixed_rate.dump(
        mint_for_testing<Meme>(1000, &mut ctx),
        min_amount_out + 1,
        &mut ctx,
    ).burn_for_testing();

    abort
}
