#[test_only]
module memez_fun::memez_burner_tests;

use memez_fun::memez_burner;
use sui::test_utils::assert_eq;

// === Structs ===

#[test]
fun test_end_to_end() {
    let expected_tax = 20;
    let expected_target_liquidity = 1000;

    let burner = memez_burner::new(
        expected_tax,
        expected_target_liquidity,
    );

    assert_eq(burner.fee().value(), expected_tax);
    assert_eq(burner.target_liquidity(), expected_target_liquidity);

    assert_eq(burner.calculate(expected_target_liquidity).value(), expected_tax);
    assert_eq(burner.calculate(expected_target_liquidity + 1).value(), expected_tax);

    assert_eq(burner.calculate(0).value(), 0);

    assert_eq(burner.calculate(900).value(), 18);
    assert_eq(burner.calculate(500).value(), 10);
    assert_eq(burner.calculate(100).value(), 2);
}

#[test]
fun test_zero() {
    let burner = memez_burner::zero();

    assert_eq(burner.fee().value(), 0);
    assert_eq(burner.calculate(0).value(), 0);
    assert_eq(burner.target_liquidity(), 0);
}

#[test]
fun test_calculate() {
    let expected_tax = 2_000;

    let burner = memez_burner::new(expected_tax, 1_100);

    assert_eq(burner.calculate(900).value(), 1637);
    assert_eq(burner.calculate(1_101).value(), expected_tax);
    assert_eq(burner.calculate(550).value(), expected_tax / 2);
    assert_eq(burner.calculate(990).value(), expected_tax - (expected_tax / 10));
    assert_eq(burner.calculate(110).value(), 200);
}
