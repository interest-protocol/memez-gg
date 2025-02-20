#[test_only]
module interest_math::d18_tests;

use interest_math::fixed18::{
    Self,
    div_up,
    mul_up,
    div_down,
    mul_down,
    try_mul_up,
    try_div_up,
    try_mul_down,
    try_div_down,
    base,
    add,
    sub,
    try_add,
    try_sub
};
use sui::test_utils::assert_eq;

const FIXED_18_BASE: u256 = 1_000_000_000_000_000_000;
// 1e18
const MAX_U256: u256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

use fun fixed18::from_raw_u256 as u256.from_raw;
use fun fixed18::from_u256 as u256.from;

#[test]
fun test_scalar() {
    assert_eq(base(), FIXED_18_BASE);
}

#[test]
fun test_add() {
    assert_eq(add(3u256.from_raw(), 5u256.from_raw()).raw_value(), 8);
}

#[test]
fun test_sub() {
    assert_eq(sub(5u256.from_raw(), 3u256.from_raw()).raw_value(), 2);
}

#[test]
fun test_convert_functions() {
    assert_eq(fixed18::from_raw_u256(3).raw_value(), 3);
    assert_eq(fixed18::from_u256(3).raw_value(), 3 * FIXED_18_BASE);

    assert_eq(fixed18::from_raw_u128(3).raw_value(), 3);
    assert_eq(fixed18::from_u128(3).raw_value(), 3 * FIXED_18_BASE);

    assert_eq(fixed18::from_raw_u64(3).raw_value(), 3);
    assert_eq(fixed18::from_u64(3).raw_value(), 3 * FIXED_18_BASE);

    assert_eq(fixed18::u64_to_fixed18(3 * 1000000000, 9).raw_value(), 3 * FIXED_18_BASE);
    assert_eq(fixed18::u64_to_fixed18(3 * 1000000000, 9).to_u64(9), 3 * 1000000000);

    assert_eq(fixed18::u128_to_fixed18(3 * 1000000000000000000, 18).raw_value(), 3 * FIXED_18_BASE);
    assert_eq(
        fixed18::u128_to_fixed18(3 * 1000000000000000000, 18).to_u128(18),
        3 * 1000000000000000000,
    );

    assert_eq(
        fixed18::u256_to_fixed18(
            3 * 100000000000000000000000000000000000000000000000000,
            50,
        ).raw_value(),
        3 * FIXED_18_BASE,
    );
    assert_eq(
        fixed18::u256_to_fixed18(
            3 * 100000000000000000000000000000000000000000000000000,
            50,
        ).to_u256(50),
        3 * 100000000000000000000000000000000000000000000000000,
    );
}

#[test]
fun test_try_add() {
    let (pred, r) = try_add(3u256.from(), 5u256.from());
    assert_eq(pred, true);
    assert_eq(r.raw_value(), 8 * FIXED_18_BASE);

    let (pred, r) = try_add(MAX_U256.from_raw(), MAX_U256.from_raw());
    assert_eq(pred, false);
    assert_eq(r.raw_value(), 0);
}

#[test]
fun test_try_sub() {
    let (pred, r) = try_sub(5u256.from(), 3u256.from());
    assert_eq(pred, true);
    assert_eq(r.raw_value(), 2 * FIXED_18_BASE);

    let (pred, r) = try_sub(3u256.from(), 5u256.from());
    assert_eq(pred, false);
    assert_eq(r.raw_value(), 0);
}

#[test]
fun test_try_mul_down() {
    let (pred, r) = try_mul_down(3u256.from(), 5u256.from());
    assert_eq(pred, true);
    assert_eq(r.raw_value(), 15 * FIXED_18_BASE);

    let (pred, r) = try_mul_down(3u256.from(), ((FIXED_18_BASE / 10) * 15).from_raw());
    assert_eq(pred, true);
    assert_eq(r.raw_value(), 45 * FIXED_18_BASE / 10);

    let (pred, r) = try_mul_down(3333333333u256.from_raw(), 23234567832u256.from_raw());
    assert_eq(pred, true);
    assert_eq(r.raw_value(), 77);

    // not enough precision
    let (pred, r) = try_mul_down(333333u256.from_raw(), 21234u256.from_raw());
    assert_eq(pred, true);
    assert_eq(r.raw_value(), 0);
    // rounds down

    let (pred, r) = try_mul_down(0u256.from(), ((FIXED_18_BASE / 10) * 15).from_raw());
    assert_eq(pred, true);
    assert_eq(r.raw_value(), 0);

    let (pred, r) = try_mul_down(MAX_U256.from_raw(), MAX_U256.from_raw());
    assert_eq(pred, false);
    assert_eq(r.raw_value(), 0);
}

#[test]
fun test_try_mul_up() {
    let (pred, r) = try_mul_up(3u256.from(), 5u256.from());
    assert_eq(pred, true);
    assert_eq(r.raw_value(), 15 * FIXED_18_BASE);

    let (pred, r) = try_mul_up(3u256.from(), ((FIXED_18_BASE / 10) * 15).from_raw());
    assert_eq(pred, true);
    assert_eq(r.raw_value(), 45 * FIXED_18_BASE / 10);

    let (pred, r) = try_mul_down(3333333333u256.from_raw(), 23234567832u256.from_raw());
    assert_eq(pred, true);
    assert_eq(r.raw_value(), 77);

    let (pred, r) = try_mul_up(333333u256.from_raw(), 21234u256.from_raw());
    assert_eq(pred, true);
    assert_eq(r.raw_value(), 1);
    // rounds up

    let (pred, r) = try_mul_up(0u256.from(), ((FIXED_18_BASE / 10) * 15).from_raw());
    assert_eq(pred, true);
    assert_eq(r.raw_value(), 0);

    let (pred, r) = try_mul_up(MAX_U256.from_raw(), MAX_U256.from_raw());
    assert_eq(pred, false);
    assert_eq(r.raw_value(), 0);
}

#[test]
fun test_try_div_down() {
    let (pred, r) = try_div_down(3u256.from(), 5u256.from());
    assert_eq(pred, true);
    assert_eq(r.raw_value(), 6 * FIXED_18_BASE / 10);

    let (pred, r) = try_div_down(3u256.from(), ((FIXED_18_BASE / 10) * 15).from_raw());
    assert_eq(pred, true);
    assert_eq(r.raw_value(), 2 * FIXED_18_BASE);
    //

    let (pred, r) = try_div_down(7u256.from(), 2u256.from());
    assert_eq(pred, true);
    assert_eq(r.raw_value(), 35 * FIXED_18_BASE / 10);

    let (pred, r) = try_div_down(0u256.from(), ((FIXED_18_BASE / 10) * 15).from_raw());
    assert_eq(pred, true);
    assert_eq(r.raw_value(), 0);

    let (pred, r) = try_div_down(333333333u256.from(), 222222221u256.from());
    assert_eq(pred, true);
    assert_eq(r.raw_value(), 1500000006750000037);
    // rounds down
    let (pred, r) = try_div_down(1u256.from(), 0u256.from());
    assert_eq(pred, false);
    assert_eq(r.raw_value(), 0);

    let (pred, r) = try_div_down(MAX_U256.from_raw(), MAX_U256.from_raw());
    // overflow
    assert_eq(pred, false);
    assert_eq(r.raw_value(), 0);
}

#[test]
fun test_try_div_up() {
    let (pred, r) = try_div_up(3u256.from(), 5u256.from());
    assert_eq(pred, true);
    assert_eq(r.raw_value(), 6 * FIXED_18_BASE / 10);

    let (pred, r) = try_div_up(3u256.from(), ((FIXED_18_BASE / 10) * 15).from_raw());
    assert_eq(pred, true);
    assert_eq(r.raw_value(), 2 * FIXED_18_BASE);
    //

    let (pred, r) = try_div_up(7u256.from(), 2u256.from());
    assert_eq(pred, true);
    assert_eq(r.raw_value(), 35 * FIXED_18_BASE / 10);

    let (pred, r) = try_div_up(0u256.from(), ((FIXED_18_BASE / 10) * 15).from_raw());
    assert_eq(pred, true);
    assert_eq(r.raw_value(), 0);

    let (pred, r) = try_div_up(333333333u256.from(), 222222221u256.from());
    assert_eq(pred, true);
    assert_eq(r.raw_value(), 1500000006750000038);
    // rounds up
    let (pred, r) = try_div_up(1u256.from(), 0u256.from());
    assert_eq(pred, false);
    assert_eq(r.raw_value(), 0);

    let (pred, r) = try_div_up(MAX_U256.from_raw(), MAX_U256.from_raw());
    // overflow
    assert_eq(pred, false);
    assert_eq(r.raw_value(), 0);
}

#[test]
fun test_mul_down() {
    assert_eq(mul_down(3u256.from(), 5u256.from()).raw_value(), 15 * FIXED_18_BASE);

    assert_eq(mul_down(333333333u256.from_raw(), 222222221u256.from_raw()).raw_value(), 0u256);

    assert_eq(mul_down(333333u256.from_raw(), 21234u256.from_raw()).raw_value(), 0u256);
    // rounds down

    assert_eq(
        mul_down(0u256.from_raw(), ((FIXED_18_BASE / 10) * 15).from_raw()).raw_value(),
        0u256,
    );
}

#[test]
fun test_mul_up() {
    assert_eq(mul_up(3u256.from(), 5u256.from()).raw_value(), 15 * FIXED_18_BASE);

    assert_eq(
        mul_up(3u256.from(), ((FIXED_18_BASE / 10) * 15).from_raw()).raw_value(),
        45 * FIXED_18_BASE / 10,
    );

    assert_eq(mul_up(333333u256.from_raw(), 21234u256.from_raw()).raw_value(), 1);
    // rounds up

    assert_eq(mul_up(0u256.from_raw(), ((FIXED_18_BASE / 10) * 15).from_raw()).raw_value(), 0);
}

#[test]
fun test_div_down() {
    assert_eq(div_down(3u256.from(), 5u256.from()).raw_value(), 6 * FIXED_18_BASE / 10);

    assert_eq(
        div_down(3u256.from(), ((FIXED_18_BASE / 10) * 15).from_raw()).raw_value(),
        2 * FIXED_18_BASE,
    );
    //

    assert_eq(div_down(7u256.from(), 2u256.from()).raw_value(), 35 * FIXED_18_BASE / 10);

    assert_eq(div_down(0u256.from(), ((FIXED_18_BASE / 10) * 15).from_raw()).raw_value(), 0);

    assert_eq(
        div_down(333333333u256.from(), 222222221u256.from()).raw_value(),
        1500000006750000037,
    );
    // rounds down
}

#[test]
fun test_div_up() {
    assert_eq(div_up(3u256.from(), 5u256.from()).raw_value(), 6 * FIXED_18_BASE / 10);

    assert_eq(
        div_up(3u256.from(), ((FIXED_18_BASE / 10) * 15).from_raw()).raw_value(),
        2 * FIXED_18_BASE,
    );
    //

    assert_eq(div_up(7u256.from(), 2u256.from()).raw_value(), 35 * FIXED_18_BASE / 10);

    assert_eq(div_up(0u256.from(), ((FIXED_18_BASE / 10) * 15).from_raw()).raw_value(), 0);

    assert_eq(div_up(333333333u256.from(), 222222221u256.from()).raw_value(), 1500000006750000038);
    // rounds up
}

#[test]
fun test_to_fixed18() {
    assert_eq(fixed18::u256_to_fixed18(FIXED_18_BASE, 18).raw_value(), FIXED_18_BASE);
    assert_eq(fixed18::u256_to_fixed18(2, 1).raw_value(), 2 * FIXED_18_BASE / 10);
    assert_eq(fixed18::u256_to_fixed18(20 * FIXED_18_BASE, 18).raw_value(), 20 * FIXED_18_BASE);

    assert_eq(fixed18::u256_to_fixed18_up(FIXED_18_BASE, 18).raw_value(), FIXED_18_BASE);
    assert_eq(fixed18::u256_to_fixed18_up(2, 1).raw_value(), (2 * FIXED_18_BASE + 9) / 10);
    assert_eq(fixed18::u256_to_fixed18_up(20 * FIXED_18_BASE, 18).raw_value(), 20 * FIXED_18_BASE);

    assert_eq(fixed18::u64_to_fixed18_up(2, 1).raw_value(), (2 * FIXED_18_BASE + 9) / 10);
    assert_eq(fixed18::u128_to_fixed18_up(2, 1).raw_value(), (2 * FIXED_18_BASE + 9) / 10);
}

#[test]
#[expected_failure]
fun test_div_down_overflow() {
    div_down(MAX_U256.from_raw(), MAX_U256.from_raw());
}

#[test]
#[expected_failure]
fun test_div_down_zero_division() {
    div_down(1u256.from_raw(), 0u256.from_raw());
}

#[test]
#[expected_failure]
fun test_div_up_zero_division() {
    div_up(1u256.from_raw(), 0u256.from_raw());
}

#[test]
#[expected_failure]
fun test_mul_up_overflow() {
    mul_up(MAX_U256.from_raw(), MAX_U256.from_raw());
}

#[test]
#[expected_failure]
fun test_mul_down_overflow() {
    mul_down(MAX_U256.from_raw(), MAX_U256.from_raw());
}
