#[test_only]
module memez_fun::memez_fixed_rate_tests;

use sui::{
    balance,
    test_utils::{assert_eq, destroy}
};

use memez_fun::memez_fixed_rate;

public struct Meme()

#[test]
fun test_new() {
    let sui_raise_amount = 1000; 
    let meme_balance_value = 5000;

    let meme_balance = balance::create_for_testing<Meme>(meme_balance_value);

    let mut fixed_rate = memez_fixed_rate::new(
        sui_raise_amount, 
        meme_balance
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