#[test_only]
module memez_fun::memez_burn_tax_tests;

use sui::test_utils::assert_eq;

use memez_fun::memez_burn_tax;

// === Structs ===  

#[test]
fun test_end_to_end() {
    let expected_tax = 20; 
    let expected_start_liquidity = 100; 
    let expected_target_liquidity = 1100; 

    let tax = memez_burn_tax::new(
        expected_tax, 
        expected_start_liquidity, 
        expected_target_liquidity
    ); 

    assert_eq(tax.tax(), expected_tax); 
    assert_eq(tax.start_liquidity(), expected_start_liquidity); 
    assert_eq(tax.target_liquidity(), expected_target_liquidity); 

    assert_eq(tax.calculate(expected_target_liquidity), 0); 
    assert_eq(tax.calculate(expected_target_liquidity + 1), 0); 

    assert_eq(tax.calculate(expected_start_liquidity - 1), expected_tax); 
    assert_eq(tax.calculate(expected_start_liquidity), expected_tax); 

    assert_eq(tax.calculate(1000), 2);
    assert_eq(tax.calculate(600), 10); 
    assert_eq(tax.calculate(200), 18); 
}