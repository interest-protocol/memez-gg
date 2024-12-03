#[test_only]
module memez_fun::memez_burner_tests;

use memez_fun::{memez_burner, memez_errors};
use sui::test_utils::assert_eq;

// === Structs ===

#[test]
fun test_end_to_end() {
    let expected_tax = 20;
    let expected_start_liquidity = 100;
    let expected_target_liquidity = 1100;

    let burner = memez_burner::new(vector[
        expected_tax,
        expected_start_liquidity,
        expected_target_liquidity,
    ]);

    assert_eq(burner.fee().value(), expected_tax);
    assert_eq(burner.start_liquidity(), expected_start_liquidity);
    assert_eq(burner.target_liquidity(), expected_target_liquidity);

    assert_eq(burner.calculate(expected_target_liquidity).value(), 0);
    assert_eq(burner.calculate(expected_target_liquidity + 1).value(), 0);

    assert_eq(burner.calculate(expected_start_liquidity - 1).value(), expected_tax);
    assert_eq(burner.calculate(expected_start_liquidity).value(), expected_tax);

    assert_eq(burner.calculate(1000).value(), 2);
    assert_eq(burner.calculate(600).value(), 10);
    assert_eq(burner.calculate(200).value(), 18);
}

#[test]
fun test_zero() {
    let burner = memez_burner::zero();

    assert_eq(burner.fee().value(), 0);
    assert_eq(burner.calculate(0).value(), 0);
    assert_eq(burner.start_liquidity(), 0);
    assert_eq(burner.target_liquidity(), 0);
}

#[test]
fun test_calculate() {
    let expected_tax = 2_000;

    let burner = memez_burner::new(vector[
        expected_tax,
        1_000,
        1_100,
    ]);

    assert_eq(burner.calculate(900).value(), expected_tax);
    assert_eq(burner.calculate(1_101).value(), 0);
    assert_eq(burner.calculate(1_050).value(), expected_tax / 2);
    assert_eq(burner.calculate(1_090).value(), expected_tax / 10);
    assert_eq(burner.calculate(1_010).value(), 1_800);
}

#[test, expected_failure(abort_code = memez_errors::EInvalidConfig, location = memez_burner)]
fun test_invalid_burn_amount() {
    memez_burner::new(vector[20, 100]);
}
