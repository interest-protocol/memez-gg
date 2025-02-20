#[test_only]
module interest_math::i64_tests;

use interest_math::i64::{
    Self,
    or,
    eq,
    lt,
    gt,
    pow,
    lte,
    gte,
    mul,
    shl,
    shr,
    abs,
    mod,
    add,
    sub,
    and,
    zero,
    value,
    div_up,
    is_negative,
    is_zero,
    div,
    from_u64,
    is_positive,
    negative_from_u64,
    truncate_to_u8,
    truncate_to_u16,
    truncate_to_u32,
    I64
};
use sui::test_utils::assert_eq;

#[test]
fun test_simple_functions() {
    assert_eq(value(one()), 1);
    assert_eq(is_zero(zero()), true);
    assert_eq(is_zero(one()), false);
    assert_eq(is_zero(negative_from_u64(1)), false);
}

#[test]
fun test_compare_functions() {
    assert_eq(eq(zero(), zero()), true);
    assert_eq(eq(zero(), one()), false);
    assert_eq(eq(negative_from_u64(2), from_u64(2)), false);

    assert_eq(lt(negative_from_u64(2), negative_from_u64(1)), true);
    assert_eq(lt(negative_from_u64(1), negative_from_u64(2)), false);
    assert_eq(lt(from_u64(2), from_u64(1)), false);
    assert_eq(lt(from_u64(1), from_u64(2)), true);
    assert_eq(lt(from_u64(2), from_u64(2)), false);

    assert_eq(lte(negative_from_u64(2), negative_from_u64(1)), true);
    assert_eq(lte(negative_from_u64(1), negative_from_u64(2)), false);
    assert_eq(lte(from_u64(2), from_u64(1)), false);
    assert_eq(lte(from_u64(1), from_u64(2)), true);
    assert_eq(lte(from_u64(2), from_u64(2)), true);

    assert_eq(gt(negative_from_u64(2), negative_from_u64(1)), false);
    assert_eq(gt(negative_from_u64(1), negative_from_u64(2)), true);
    assert_eq(gt(from_u64(2), from_u64(1)), true);
    assert_eq(gt(from_u64(1), from_u64(2)), false);
    assert_eq(gt(from_u64(2), from_u64(2)), false);

    assert_eq(gte(negative_from_u64(2), negative_from_u64(1)), false);
    assert_eq(gte(negative_from_u64(1), negative_from_u64(2)), true);
    assert_eq(gte(from_u64(2), from_u64(1)), true);
    assert_eq(gte(from_u64(1), from_u64(2)), false);
    assert_eq(gte(from_u64(2), from_u64(2)), true);
}

#[test]
fun test_truncate_to_u8() {
    assert_eq(truncate_to_u8(from_u64(0x1234567890)), 0x90);
    assert_eq(truncate_to_u8(from_u64(0xABCDEF)), 0xEF);
    assert_eq(
        truncate_to_u8(
            from_u64(0x7FFFFFFFFFFFFFFF),
        ),
        255,
    );
    assert_eq(truncate_to_u8(from_u64(256)), 0);
    assert_eq(truncate_to_u8(from_u64(511)), 255);
    assert_eq(truncate_to_u8(negative_from_u64(230)), 26);
}

#[test]
fun test_truncate_to_u16() {
    assert_eq(truncate_to_u16(from_u64(0)), 0);
    assert_eq(truncate_to_u16(from_u64(65535)), 65535);
    assert_eq(truncate_to_u16(from_u64(65536)), 0);
    assert_eq(truncate_to_u16(negative_from_u64(32768)), 32768);
    assert_eq(
        truncate_to_u16(
            from_u64(0x7FFFFFFFFFFFFFFF),
        ),
        65535,
    );
    assert_eq(truncate_to_u16(from_u64(12345)), 12345);
    assert_eq(truncate_to_u16(negative_from_u64(9876)), 55660);
    assert_eq(truncate_to_u16(from_u64(196608)), 0);
    assert_eq(truncate_to_u16(from_u64(32768)), 32768);
    assert_eq(truncate_to_u16(from_u64(50000)), 50000);
}

#[test]
fun test_truncate_to_u32() {
    assert_eq(truncate_to_u32(negative_from_u64(2147483648)), 2147483648);
    assert_eq(truncate_to_u32(from_u64(4294967295)), 4294967295);
    assert_eq(truncate_to_u32(from_u64(4294967296)), 0);
    assert_eq(truncate_to_u32(negative_from_u64(123456789)), 4171510507);
    assert_eq(truncate_to_u32(from_u64(987654321)), 987654321);
    assert_eq(truncate_to_u32(negative_from_u64(876543210)), 3418424086);
    assert_eq(truncate_to_u32(from_u64(2147483648)), 2147483648);
    assert_eq(truncate_to_u32(negative_from_u64(2147483648)), 2147483648);
    assert_eq(truncate_to_u32(from_u64(1073741824)), 1073741824);
    assert_eq(truncate_to_u32(from_u64(305419896)), 305419896);
}

#[test]
fun test_compare() {
    assert_eq(eq(from_u64(123), from_u64(123)), true);
    assert_eq(eq(negative_from_u64(123), negative_from_u64(123)), true);
    assert_eq(eq(from_u64(234), from_u64(123)), false);
    assert_eq(lt(from_u64(123), from_u64(234)), true);
    assert_eq(lt(negative_from_u64(234), negative_from_u64(123)), true);
    assert_eq(gt(negative_from_u64(123), negative_from_u64(234)), true);
    assert_eq(gt(from_u64(123), negative_from_u64(234)), true);
    assert_eq(lt(negative_from_u64(123), from_u64(234)), true);
    assert_eq(gt(from_u64(234), negative_from_u64(123)), true);
    assert_eq(lt(negative_from_u64(234), from_u64(123)), true);
}

#[test]
fun test_add() {
    assert_eq(add(from_u64(123), from_u64(234)), from_u64(357));
    assert_eq(add(from_u64(123), negative_from_u64(234)), negative_from_u64(111));
    assert_eq(add(from_u64(234), negative_from_u64(123)), from_u64(111));
    assert_eq(add(negative_from_u64(123), from_u64(234)), from_u64(111));
    assert_eq(add(negative_from_u64(123), negative_from_u64(234)), negative_from_u64(357));
    assert_eq(add(negative_from_u64(234), negative_from_u64(123)), negative_from_u64(357));
    assert_eq(add(from_u64(123), negative_from_u64(123)), zero());
    assert_eq(add(negative_from_u64(123), from_u64(123)), zero());
}

#[test]
fun test_sub() {
    assert_eq(sub(from_u64(123), from_u64(234)), negative_from_u64(111));
    assert_eq(sub(from_u64(234), from_u64(123)), from_u64(111));
    assert_eq(sub(from_u64(123), negative_from_u64(234)), from_u64(357));
    assert_eq(sub(negative_from_u64(123), from_u64(234)), negative_from_u64(357));
    assert_eq(sub(negative_from_u64(123), negative_from_u64(234)), from_u64(111));
    assert_eq(sub(negative_from_u64(234), negative_from_u64(123)), negative_from_u64(111));
    assert_eq(sub(from_u64(123), from_u64(123)), zero());
    assert_eq(sub(negative_from_u64(123), negative_from_u64(123)), zero());
}

#[test]
fun test_mul() {
    assert_eq(mul(from_u64(123), from_u64(234)), from_u64(28782));
    assert_eq(mul(from_u64(123), negative_from_u64(234)), negative_from_u64(28782));
    assert_eq(mul(negative_from_u64(123), from_u64(234)), negative_from_u64(28782));
    assert_eq(mul(negative_from_u64(123), negative_from_u64(234)), from_u64(28782));
}

#[test]
fun test_div_down() {
    assert_eq(div(from_u64(28781), from_u64(123)), from_u64(233));
    assert_eq(div(from_u64(28781), negative_from_u64(123)), negative_from_u64(233));
    assert_eq(div(negative_from_u64(28781), from_u64(123)), negative_from_u64(233));
    assert_eq(div(negative_from_u64(28781), negative_from_u64(123)), from_u64(233));
}

#[test]
fun test_div_up() {
    assert_eq(div_up(from_u64(512), from_u64(256)), from_u64(2));
    assert_eq(div_up(from_u64(768), from_u64(256)), from_u64(3));
    assert_eq(div_up(negative_from_u64(512), from_u64(256)), negative_from_u64(2));
    assert_eq(div_up(negative_from_u64(768), from_u64(256)), negative_from_u64(3));
    assert_eq(div_up(from_u64(12345), from_u64(1)), from_u64(12345));
    assert_eq(div_up(from_u64(0), from_u64(256)), from_u64(0));
    assert_eq(div_up(from_u64(701), from_u64(200)), from_u64(4));
    assert_eq(div_up(from_u64(701), negative_from_u64(200)), negative_from_u64(4));
}

#[test]
fun test_shl() {
    assert_eq(eq(shl(from_u64(42), 0), from_u64(42)), true);
    assert_eq(eq(shl(from_u64(42), 1), from_u64(84)), true);
    assert_eq(eq(shl(negative_from_u64(42), 2), negative_from_u64(168)), true);
    assert_eq(eq(shl(zero(), 5), zero()), true);
    assert_eq(eq(shl(from_u64(42), 63), zero()), true);
    assert_eq(eq(shl(from_u64(5), 3), from_u64(40)), true);
    assert_eq(eq(shl(negative_from_u64(5), 3), negative_from_u64(40)), true);
    assert_eq(eq(shl(negative_from_u64(123456789), 5), negative_from_u64(3950617248)), true);
}

#[test]
fun test_abs() {
    assert_eq(value(from_u64(10)), value(abs(negative_from_u64(10))));
    assert_eq(value(from_u64(12826189)), value(abs(negative_from_u64(12826189))));
    assert_eq(value(from_u64(10)), value(abs(from_u64(10))));
    assert_eq(value(from_u64(12826189)), value(abs(from_u64(12826189))));
    assert_eq(value(from_u64(0)), value(abs(from_u64(0))));
}

#[test]
fun test_pow() {
    assert_eq(pow(from_u64(0), 0), one());
    assert_eq(pow(from_u64(0), 1), zero());
    assert_eq(pow(from_u64(0), 112345), zero());
    assert_eq(pow(from_u64(1), 112345), one());
    assert_eq(pow(from_u64(1), 0), one());
    assert_eq(pow(from_u64(12345), 1), from_u64(12345));
    assert_eq(pow(from_u64(2), 3), from_u64(8));
    assert_eq(pow(negative_from_u64(2), 3), negative_from_u64(8));
    assert_eq(pow(from_u64(2), 4), from_u64(16));
    assert_eq(pow(negative_from_u64(2), 4), from_u64(16));
}

#[test]
fun test_neg_from() {
    assert_eq(value(negative_from_u64(10)), 18446744073709551606);
    assert_eq(value(negative_from_u64(100)), 18446744073709551516);
}

#[test]
fun test_shr() {
    assert_eq(shr(negative_from_u64(10), 1), negative_from_u64(5));
    assert_eq(shr(negative_from_u64(25), 3), negative_from_u64(4));
    assert_eq(shr(negative_from_u64(2147483648), 1), negative_from_u64(1073741824));
    assert_eq(shr(negative_from_u64(123456789), 32), negative_from_u64(1));
    assert_eq(shr(negative_from_u64(987654321), 40), negative_from_u64(1));
    assert_eq(shr(negative_from_u64(42), 63), negative_from_u64(1));
    assert_eq(shr(negative_from_u64(0), 63), negative_from_u64(0));
    assert_eq(shr(from_u64(0), 20), from_u64(0));
}

#[test]
fun test_or() {
    assert_eq(or(zero(), zero()), zero());
    assert_eq(or(zero(), negative_from_u64(1)), negative_from_u64(1));
    assert_eq(or(negative_from_u64(1), negative_from_u64(1)), negative_from_u64(1));
    assert_eq(or(negative_from_u64(1), from_u64(1)), negative_from_u64(1));
    assert_eq(or(from_u64(10), from_u64(5)), from_u64(15));
    assert_eq(or(negative_from_u64(10), negative_from_u64(5)), negative_from_u64(1));
    assert_eq(or(negative_from_u64(10), negative_from_u64(4)), negative_from_u64(2));
}

#[test]
fun test_is_neg() {
    assert_eq(is_negative(zero()), false);
    assert_eq(is_negative(negative_from_u64(5)), true);
    assert_eq(is_negative(from_u64(172)), false);
}

#[test]
fun test_is_positive() {
    assert_eq(is_positive(zero()), true);
    assert_eq(is_positive(negative_from_u64(5)), false);
    assert_eq(is_positive(from_u64(172)), true);
}

#[test]
fun test_and() {
    assert_eq(and(zero(), zero()), zero());
    assert_eq(and(zero(), negative_from_u64(1)), zero());
    assert_eq(and(negative_from_u64(1), negative_from_u64(1)), negative_from_u64(1));
    assert_eq(and(negative_from_u64(1), from_u64(1)), from_u64(1));
    assert_eq(and(from_u64(10), from_u64(5)), zero());
    assert_eq(and(negative_from_u64(10), negative_from_u64(5)), negative_from_u64(14));
}

#[test]
fun test_mod() {
    assert_eq(mod(negative_from_u64(100), negative_from_u64(30)), negative_from_u64(10));
    assert_eq(mod(negative_from_u64(100), negative_from_u64(30)), negative_from_u64(10));
    assert_eq(mod(from_u64(100), negative_from_u64(30)), from_u64(10));
    assert_eq(mod(from_u64(100), from_u64(30)), from_u64(10));
    assert_eq(mod(from_u64(1234567890), from_u64(987654321)), from_u64(246913569));
}

#[test]
fun test_wrapping_add() {
    // Basic positive number addition
    assert_eq(from_u64(5).wrapping_add(from_u64(3)), from_u64(8));

    // Adding Zero
    assert_eq(from_u64(42).wrapping_add(from_u64(0)), from_u64(42));

    // Negative number (in two's complement)
    assert_eq(
        negative_from_u64(2).wrapping_add(negative_from_u64(3)),
        negative_from_u64(5),
    );

    // Mixed positive and negative numbers
    assert_eq(
        from_u64(10).wrapping_add(negative_from_u64(15)),
        negative_from_u64(5),
    );
    assert_eq(
        negative_from_u64(10).wrapping_add(from_u64(15)),
        from_u64(5),
    );

    // Maximum overflow
    assert_eq(i64::max().wrapping_add(from_u64(1)), i64::min());
    assert_eq(
        i64::max().wrapping_add(from_u64(5)),
        i64::min().wrapping_add(from_u64(4)),
    );

    // Minimum underflow
    assert_eq(
        i64::min().wrapping_add(negative_from_u64(1)),
        i64::max(),
    );
    assert_eq(
        i64::min().wrapping_add(negative_from_u64(5)),
        i64::max().wrapping_add(negative_from_u64(4)),
    );

    // Maximum + Maximum
    assert_eq(
        i64::max().wrapping_add(i64::max()),
        negative_from_u64(2),
    );

    // Minimum + Minimum
    assert_eq(i64::min().wrapping_add(i64::min()), from_u64(0));

    // Any number - 1 should decrement the number
    assert_eq(
        from_u64(123).wrapping_add(negative_from_u64(1)),
        from_u64(122),
    );

    // Zero + Any number should be the same number
    assert_eq(from_u64(123).wrapping_add(from_u64(0)), from_u64(123));
}

#[test]
fun test_wrapping_sub() {
    // Basic positive subtraction
    assert_eq(from_u64(8).wrapping_sub(from_u64(3)), from_u64(5));

    // Subtracting zero
    assert_eq(from_u64(8).wrapping_sub(from_u64(0)), from_u64(8));
    assert_eq(
        from_u64(0).wrapping_sub(from_u64(8)),
        negative_from_u64(8),
    );
    assert_eq(from_u64(0).wrapping_sub(from_u64(0)), from_u64(0));
    assert_eq(
        negative_from_u64(0).wrapping_sub(from_u64(0)),
        negative_from_u64(0),
    );

    // Subtracting a negative number
    assert_eq(
        negative_from_u64(5).wrapping_sub(negative_from_u64(3)),
        negative_from_u64(2),
    );

    // Positive and negative subtraction
    assert_eq(
        from_u64(5).wrapping_sub(negative_from_u64(3)),
        from_u64(8),
    );
    assert_eq(
        negative_from_u64(5).wrapping_sub(from_u64(3)),
        negative_from_u64(8),
    );

    // Subtracting a larger number
    assert_eq(
        from_u64(8).wrapping_sub(from_u64(11)),
        negative_from_u64(3),
    );

    // Subtracting a negative number from_u32 a positive number
    assert_eq(
        negative_from_u64(5).wrapping_sub(from_u64(3)),
        negative_from_u64(8),
    );

    // Minimum + Max
    assert_eq(i64::max().wrapping_sub(i64::max()), from_u64(0));

    assert_eq(
        i64::max().wrapping_sub(i64::max()).wrapping_sub(i64::max()),
        i64::min().add(from_u64(1)),
    );

    assert_eq(
        i64::max().wrapping_sub(negative_from_u64(1)),
        i64::min(),
    );
    assert_eq(i64::min().wrapping_sub(from_u64(1)), i64::max());
}

#[test, expected_failure(abort_code = i64::EDivByZero, location = i64)]
fun test_mod_by_zero() {
    mod(from_u64(123), zero());
}

#[test, expected_failure(abort_code = i64::EInvalidBitShift, location = i64)]
fun test_invalid_shl() {
    shl(from_u64(1), 64);
}

#[test, expected_failure(abort_code = i64::EInvalidBitShift, location = i64)]
fun test_invalid_shr() {
    shr(from_u64(1), 64);
}

fun one(): I64 {
    from_u64(1)
}
