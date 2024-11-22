#[test_only]
module memez_fun::memez_constant_product_tests;

use constant_product::constant_product::get_amount_out;
use interest_math::u64;
use ipx_coin_standard::ipx_coin_standard;
use memez_fun::{memez_burn_tax, memez_constant_product, memez_utils};
use sui::{balance, coin::{Self, mint_for_testing}, sui::SUI, test_utils::{assert_eq, destroy}};

// === Imports ===

public struct Meme has drop ()

const POW_9: u64 = 1__000_000_000;

#[test]
fun test_new() {
    let virtual_liquidity = 100;
    let target_sui_liquidity = 1100;
    let meme_balance_value = 5000;
    let burn_tax = 20;

    let cp = memez_constant_product::new(
        virtual_liquidity,
        target_sui_liquidity,
        balance::create_for_testing<Meme>(meme_balance_value),
        burn_tax,
    );

    assert_eq(cp.virtual_liquidity(), virtual_liquidity);
    assert_eq(cp.target_sui_liquidity(), target_sui_liquidity);
    assert_eq(cp.meme_balance().value(), meme_balance_value);
    assert_eq(cp.burn_tax().tax(), burn_tax);
    assert_eq(cp.burn_tax().start_liquidity(), virtual_liquidity);
    assert_eq(cp.burn_tax().target_liquidity(), target_sui_liquidity);

    destroy(cp);
}

#[test]
fun test_set_memez_fun() {
    let mut cp = memez_constant_product::new(
        100,
        1100,
        balance::create_for_testing<Meme>(5000),
        20,
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
    let burn_tax = 20;

    let mut cp = memez_constant_product::new(
        virtual_liquidity,
        target_sui_liquidity,
        balance::create_for_testing<Meme>(meme_balance_value),
        burn_tax,
    );

    let amount_in = 250;

    let amount_out = get_amount_out(
        amount_in,
        virtual_liquidity,
        meme_balance_value,
    );

    let expected_amount_out = cp.pump_amount(amount_in, 0);

    let (can_migrate, coin_meme_out) = cp.pump(
        mint_for_testing<SUI>(amount_in, &mut ctx),
        0,
        &mut ctx,
    );

    assert_eq(can_migrate, false);
    assert_eq(coin_meme_out.value(), expected_amount_out);
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

    let expected_amount_out = cp.pump_amount(amount_in, 0);

    let (can_migrate, coin_meme_out) = cp.pump(
        mint_for_testing<SUI>(amount_in, &mut ctx),
        0,
        &mut ctx,
    );

    assert_eq(can_migrate, true);
    assert_eq(coin_meme_out.value(), expected_amount_out);
    assert_eq(coin_meme_out.burn_for_testing(), amount_out);
    assert_eq(cp.sui_balance().value(), amount_in + new_sui_balance);
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
    let burn_tax = 20;

    let mut meme_treasury_cap = coin::create_treasury_cap_for_testing<Meme>(&mut ctx);

    let mut cp = memez_constant_product::new(
        virtual_liquidity,
        target_sui_liquidity,
        meme_treasury_cap.mint(meme_balance_value, &mut ctx).into_balance(),
        burn_tax,
    );

    let burn_tax = memez_burn_tax::new(burn_tax, virtual_liquidity, target_sui_liquidity);

    let (mut ipx_treasury, mut witness) = ipx_coin_standard::new(meme_treasury_cap, &mut ctx);

    witness.add_burn_capability(&mut ipx_treasury);

    let sui_amount_in = 500;

    let (_, coin_meme_out) = cp.pump(
        mint_for_testing<SUI>(sui_amount_in, &mut ctx),
        0,
        &mut ctx,
    );

    let meme_coin_out_value = coin_meme_out.value();

    let (expected_sui_coin_out, fee) = cp.dump_amount(meme_coin_out_value, 0);

    let pre_tax_amount_out = get_amount_out(
        meme_coin_out_value,
        cp.meme_balance().value(),
        cp.sui_balance().value() + virtual_liquidity,
    );

    let fee_rate = burn_tax.calculate(
        cp.sui_balance().value() + virtual_liquidity - pre_tax_amount_out,
    );

    let amount_out = get_amount_out(
        meme_coin_out_value - fee,
        cp.meme_balance().value(),
        cp.sui_balance().value() + virtual_liquidity,
    );

    let meme_fee_value = u64::mul_div_up(meme_coin_out_value, fee_rate, POW_9);

    let sui_coin_out = cp.dump(
        &mut ipx_treasury,
        coin_meme_out,
        expected_sui_coin_out,
        &mut ctx,
    );

    assert_eq(meme_fee_value, fee);
    assert_eq(ipx_treasury.total_supply<Meme>(), meme_balance_value - fee);
    assert_eq(amount_out, expected_sui_coin_out);

    assert_eq(cp.sui_balance().value(), sui_amount_in - expected_sui_coin_out);
    assert_eq(cp.meme_balance().value(), meme_balance_value - fee);

    sui_coin_out.burn_for_testing();

    destroy(ipx_treasury);
    destroy(cp);
}

#[test]
fun test_pump_amount() {
    let virtual_liquidity = 100;
    let target_sui_liquidity = 1100;
    let meme_balance_value = 5000;
    let burn_tax = 20;

    let cp = memez_constant_product::new(
        virtual_liquidity,
        target_sui_liquidity,
        balance::create_for_testing<Meme>(meme_balance_value),
        burn_tax,
    );

    let amount_in = 250;

    let amount_out = get_amount_out(
        amount_in,
        virtual_liquidity,
        meme_balance_value + 1200,
    );

    let expected_amount_out = cp.pump_amount(amount_in, 1200);

    assert_eq(expected_amount_out, amount_out);

    assert_eq(cp.pump_amount(0, 1200), 0);

    destroy(cp);
}

#[test]
fun test_dump_amount() {
    let virtual_liquidity = 100;
    let target_sui_liquidity = 1100;
    let meme_balance_value = 5000;
    let burn_tax = 20;

    let mut cp = memez_constant_product::new(
        virtual_liquidity,
        target_sui_liquidity,
        balance::create_for_testing<Meme>(meme_balance_value),
        burn_tax,
    );

    let amount_in = 1000;

    let amount_out = get_amount_out(
        amount_in,
        meme_balance_value + 1200,
        virtual_liquidity,
    );

    let (expected_amount_out, _) = cp.dump_amount(amount_in, 1200);

    assert_eq(expected_amount_out, 0);
    assert_eq(amount_out != 0, true);
    assert_eq(expected_amount_out, 0);

    cp.sui_balance_mut().join(balance::create_for_testing<SUI>(600));

    let amount_out = get_amount_out(
        amount_in,
        meme_balance_value + 1200,
        virtual_liquidity + 600,
    );

    let (expected_amount_out, _) = cp.dump_amount(amount_in, 1200);

    assert_eq(expected_amount_out, amount_out);

    let (expected_amount_out, fee) = cp.dump_amount(0, 1200);

    assert_eq(expected_amount_out, 0);
    assert_eq(fee, 0);

    destroy(cp);
}

#[test]
#[expected_failure(abort_code = memez_utils::EZeroCoin, location = memez_utils)]
fun test_pump_zero_coin() {
    let mut ctx = tx_context::dummy();

    let virtual_liquidity = 100;
    let target_sui_liquidity = 1100;
    let meme_balance_value = 5000;
    let burn_tax = 20;

    let mut cp = memez_constant_product::new(
        virtual_liquidity,
        target_sui_liquidity,
        balance::create_for_testing<Meme>(meme_balance_value),
        burn_tax,
    );

    let (_, coin_meme_out) = cp.pump(
        coin::zero(&mut ctx),
        0,
        &mut ctx,
    );

    coin_meme_out.burn_for_testing();

    destroy(cp);
}

#[test]
#[expected_failure(abort_code = memez_utils::ESlippage, location = memez_utils)]
fun test_pump_slippage() {
    let mut ctx = tx_context::dummy();

    let virtual_liquidity = 100;
    let target_sui_liquidity = 1100;
    let meme_balance_value = 5000;
    let burn_tax = 20;

    let mut cp = memez_constant_product::new(
        virtual_liquidity,
        target_sui_liquidity,
        balance::create_for_testing<Meme>(meme_balance_value),
        burn_tax,
    );

    let amount_in = 250;

    let expected_amount_out = cp.pump_amount(amount_in, 0);

    let (_, coin_meme_out) = cp.pump(
        mint_for_testing<SUI>(amount_in, &mut ctx),
        expected_amount_out + 1,
        &mut ctx,
    );

    coin_meme_out.burn_for_testing();

    destroy(cp);
}

#[test]
#[expected_failure(abort_code = memez_utils::EZeroCoin, location = memez_utils)]
fun test_dump_zero_coin() {
    let mut ctx = tx_context::dummy();

    let virtual_liquidity = 100;
    let target_sui_liquidity = 1100;
    let meme_balance_value = 5000;
    let burn_tax = 20;

    let meme_treasury_cap = coin::create_treasury_cap_for_testing<Meme>(&mut ctx);

    let (mut ipx_treasury, _) = ipx_coin_standard::new(meme_treasury_cap, &mut ctx);

    let mut cp = memez_constant_product::new(
        virtual_liquidity,
        target_sui_liquidity,
        balance::create_for_testing<Meme>(meme_balance_value),
        burn_tax,
    );

    let sui_coin_out = cp.dump(
        &mut ipx_treasury,
        coin::zero(&mut ctx),
        0,
        &mut ctx,
    );

    sui_coin_out.burn_for_testing();

    destroy(ipx_treasury);
    destroy(cp);
}

#[test]
#[expected_failure(abort_code = memez_utils::ESlippage, location = memez_utils)]
fun test_dump_slippage() {
    let mut ctx = tx_context::dummy();

    let virtual_liquidity = 100;
    let target_sui_liquidity = 1100;
    let meme_balance_value = 5000;
    let burn_tax = 20;

    let mut meme_treasury_cap = coin::create_treasury_cap_for_testing<Meme>(&mut ctx);

    let mut cp = memez_constant_product::new(
        virtual_liquidity,
        target_sui_liquidity,
        meme_treasury_cap.mint(meme_balance_value, &mut ctx).into_balance(),
        burn_tax,
    );

    let (mut ipx_treasury, mut witness) = ipx_coin_standard::new(meme_treasury_cap, &mut ctx);

    witness.add_burn_capability(&mut ipx_treasury);

    let sui_amount_in = 500;

    let (_, coin_meme_out) = cp.pump(
        mint_for_testing<SUI>(sui_amount_in, &mut ctx),
        0,
        &mut ctx,
    );

    let meme_coin_out_value = coin_meme_out.value();

    let (expected_sui_coin_out, _) = cp.dump_amount(meme_coin_out_value, 0);

    let sui_coin_out = cp.dump(
        &mut ipx_treasury,
        coin_meme_out,
        expected_sui_coin_out + 1,
        &mut ctx,
    );

    sui_coin_out.burn_for_testing();

    destroy(ipx_treasury);
    destroy(cp);
}
