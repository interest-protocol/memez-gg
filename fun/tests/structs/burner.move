// #[test_only]
// module memez_fun::memez_burner_tests;

// use memez_fun::memez_burner;
// use sui::test_utils::assert_eq;

// // === Structs ===

// #[test]
// fun test_end_to_end() {
//     let expected_tax = 20;
//     let expected_start_liquidity = 100;
//     let expected_target_liquidity = 1100;

//     let burner = memez_burner::new(vector[
//         expected_tax,
//         expected_start_liquidity,
//         expected_target_liquidity,
//     ]);

//     assert_eq(burner.value(), expected_tax);
//     assert_eq(burner.start_liquidity(), expected_start_liquidity);
//     assert_eq(burner.target_liquidity(), expected_target_liquidity);

//     assert_eq(burner.calculate(expected_target_liquidity), 0);
//     assert_eq(burner.calculate(expected_target_liquidity + 1), 0);

//     assert_eq(burner.calculate(expected_start_liquidity - 1), expected_tax);
//     assert_eq(burner.calculate(expected_start_liquidity), expected_tax);

//     assert_eq(burner.calculate(1000), 2);
//     assert_eq(burner.calculate(600), 10);
//     assert_eq(burner.calculate(200), 18);
// }
