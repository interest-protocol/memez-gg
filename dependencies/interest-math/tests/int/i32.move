#[test_only]
module interest_math::i32_tests;

use interest_math::i32::{Self, from_u32, negative_from_u64 as negative_from};
use sui::test_utils::assert_eq;

#[test]
fun test_simple_functions() {
    assert_eq(i32::zero().value(), 0);
    assert_eq(i32::max().value(), 2147483647);
    assert_eq(i32::min().value(), 2147483648);
    assert_eq(i32::from_u32(1).value(), 1);
    assert_eq(from_u32(2147483647).value(), 2147483647);
    assert_eq(negative_from(2147483648).value(), 2147483648);
}

#[test]
fun test_compare_functions() {
    assert_eq(i32::eq(i32::zero(), i32::zero()), true);
    assert_eq(i32::eq(i32::zero(), from_u32(1)), false);
    assert_eq(i32::eq(negative_from(2), from_u32(2)), false);

    assert_eq(
        i32::lt(negative_from(2), negative_from(1)),
        true,
    );
    assert_eq(
        i32::lt(negative_from(1), negative_from(2)),
        false,
    );
    assert_eq(i32::lt(from_u32(2), from_u32(1)), false);
    assert_eq(i32::lt(from_u32(1), from_u32(2)), true);
    assert_eq(i32::lt(from_u32(2), from_u32(2)), false);

    assert_eq(
        i32::lte(negative_from(2), negative_from(1)),
        true,
    );
    assert_eq(
        i32::lte(negative_from(1), negative_from(2)),
        false,
    );
    assert_eq(i32::lte(from_u32(2), from_u32(1)), false);
    assert_eq(i32::lte(from_u32(1), from_u32(2)), true);
    assert_eq(i32::lte(from_u32(2), from_u32(2)), true);

    assert_eq(
        i32::gt(negative_from(2), negative_from(1)),
        false,
    );
    assert_eq(
        i32::gt(negative_from(1), negative_from(2)),
        true,
    );
    assert_eq(i32::gt(from_u32(2), from_u32(1)), true);
    assert_eq(i32::gt(from_u32(1), from_u32(2)), false);
    assert_eq(i32::gt(from_u32(2), from_u32(2)), false);

    assert_eq(
        i32::gte(negative_from(2), negative_from(1)),
        false,
    );
    assert_eq(
        i32::gte(negative_from(1), negative_from(2)),
        true,
    );
    assert_eq(i32::gte(from_u32(2), from_u32(1)), true);
    assert_eq(i32::gte(from_u32(2), from_u32(2)), true);
}

#[test]
fun test_truncate_to_u8() {
    assert_eq(i32::truncate_to_u8(i32::max()), 255);
    assert_eq(i32::truncate_to_u8(negative_from(230)), 26);
}

#[test]
fun test_truncate_to_u16() {
    assert_eq(i32::truncate_to_u16(from_u32(0)), 0);
    assert_eq(i32::truncate_to_u16(from_u32(65535)), 65535);
    assert_eq(i32::truncate_to_u16(from_u32(65536)), 0);
    assert_eq(i32::truncate_to_u16(negative_from(32768)), 32768);
    assert_eq(i32::truncate_to_u16(i32::max()), 65535);
    assert_eq(i32::truncate_to_u16(from_u32(12345)), 12345);
    assert_eq(i32::truncate_to_u16(negative_from(9876)), 55660);
    assert_eq(i32::truncate_to_u16(from_u32(32768)), 32768);
    assert_eq(i32::truncate_to_u16(from_u32(50000)), 50000);
}

#[test]
fun test_compare() {
    assert_eq(from_u32(123).eq(from_u32(123)), true);
    assert_eq(
        negative_from(123).eq(negative_from(123)),
        true,
    );

    assert_eq(from_u32(123).lt(from_u32(234)), true);
    assert_eq(from_u32(234).gt(from_u32(123)), true);

    assert_eq(
        negative_from(234).lt(negative_from(123)),
        true,
    );
    assert_eq(
        negative_from(123).gt(negative_from(234)),
        true,
    );

    assert_eq(negative_from(123).lt(from_u32(234)), true);
    assert_eq(from_u32(123).gt(negative_from(234)), true);

    assert_eq(negative_from(123).lte(from_u32(1)), true);
    assert_eq(from_u32(234).gte(from_u32(123)), true);

    assert_eq(negative_from(123).lte(from_u32(1)), true);
    assert_eq(from_u32(234).gte(from_u32(123)), true);

    assert_eq(from_u32(123).gte(from_u32(123)), true);
    assert_eq(from_u32(123).lte(from_u32(123)), true);

    assert_eq(
        negative_from(123).gte(negative_from(123)),
        true,
    );
    assert_eq(
        negative_from(123).lte(negative_from(123)),
        true,
    );
}

#[test]
fun test_add() {
    // Basic positive number addition
    assert_eq(from_u32(5).add(from_u32(3)), from_u32(8));

    // Adding Zero
    assert_eq(from_u32(42).add(from_u32(0)), from_u32(42));

    // Negative number (in two's complement)
    assert_eq(
        negative_from(2).add(negative_from(3)),
        negative_from(5),
    );

    // Mixed positive and negative numbers
    assert_eq(
        from_u32(10).add(negative_from(15)),
        negative_from(5),
    );
    assert_eq(negative_from(10).add(from_u32(15)), from_u32(5));

    // Minimum + Max
    assert_eq(i32::min().add(i32::max()), negative_from(1));

    // Any number - 1 should decrement the number
    assert_eq(from_u32(123).add(negative_from(1)), from_u32(122));

    // Zero + Any number should be the same number
    assert_eq(from_u32(123).add(from_u32(0)), from_u32(123));
}

#[test, expected_failure(abort_code = i32::EOverflow, location = i32)]
fun test_add_overflow() {
    i32::max().add(from_u32(1));
}

#[test, expected_failure(abort_code = i32::EOverflow, location = i32)]
fun test_add_underflow() {
    i32::min().add(negative_from(1));
}

#[test]
fun test_sub() {
    // Basic positive subtraction
    assert_eq(from_u32(8).sub(from_u32(3)), from_u32(5));

    // Subtracting zero
    assert_eq(from_u32(8).sub(from_u32(0)), from_u32(8));
    assert_eq(from_u32(0).sub(from_u32(8)), negative_from(8));
    assert_eq(from_u32(0).sub(from_u32(0)), from_u32(0));
    assert_eq(
        negative_from(0).sub(from_u32(0)),
        negative_from(0),
    );

    // Subtracting a negative number
    assert_eq(
        negative_from(5).sub(negative_from(3)),
        negative_from(2),
    );

    // Positive and negative subtraction
    assert_eq(from_u32(5).sub(negative_from(3)), from_u32(8));
    assert_eq(
        negative_from(5).sub(from_u32(3)),
        negative_from(8),
    );

    // Subtracting a larger number
    assert_eq(from_u32(8).sub(from_u32(11)), negative_from(3));

    // Subtracting a negative number from_u32 a positive number
    assert_eq(
        negative_from(5).sub(from_u32(3)),
        negative_from(8),
    );

    // Minimum + Max
    assert_eq(i32::max().sub(i32::max()), from_u32(0));

    assert_eq(
        i32::max().sub(i32::max()).sub(i32::max()),
        i32::min().add(from_u32(1)),
    );
}

#[test, expected_failure(abort_code = i32::EOverflow, location = i32)]
fun test_sub_overflow() {
    i32::max().sub(negative_from(1));
}

#[test, expected_failure(abort_code = i32::EOverflow, location = i32)]
fun test_sub_underflow() {
    i32::min().sub(from_u32(1));
}

#[test]
fun test_mul() {
    // Basic Positive Multiplication
    assert_eq(from_u32(5).mul(from_u32(3)), from_u32(15));

    // Multiplying by Zero
    assert_eq(from_u32(123).mul(from_u32(0)), from_u32(0));
    assert_eq(from_u32(0).mul(from_u32(123)), from_u32(0));

    // Multiplying by One
    assert_eq(from_u32(123).mul(from_u32(1)), from_u32(123));
    assert_eq(from_u32(1).mul(from_u32(123)), from_u32(123));

    // Multiplying by Negative Number
    assert_eq(
        from_u32(123).mul(negative_from(3)),
        negative_from(369),
    );
    assert_eq(
        negative_from(123).mul(from_u32(3)),
        negative_from(369),
    );

    // Multiple Positive By Negative
    assert_eq(
        from_u32(123).mul(negative_from(3)),
        negative_from(369),
    );
    assert_eq(
        negative_from(123).mul(from_u32(3)),
        negative_from(369),
    );

    // Multiple Negative By Positive
    assert_eq(
        negative_from(123).mul(from_u32(3)),
        negative_from(369),
    );
    assert_eq(
        from_u32(123).mul(negative_from(3)),
        negative_from(369),
    );

    // Multiple Negative By Negative
    assert_eq(
        negative_from(123).mul(negative_from(3)),
        from_u32(369),
    );

    // Near Maximum
    assert_eq(
        i32::max().div(from_u32(2)).mul(from_u32(2)),
        i32::max().sub(from_u32(1)),
    );

    // Near Minimum
    assert_eq(
        i32::min().div(from_u32(2)).mul(from_u32(2)),
        i32::min(),
    );
}

#[test]
fun test_div() {
    // Basic Positive Division
    assert_eq(from_u32(15).div(from_u32(3)), from_u32(5));

    // Dividing by one
    assert_eq(from_u32(123).div(from_u32(1)), from_u32(123));

    // Division of zero
    assert_eq(from_u32(0).div(from_u32(123)), from_u32(0));

    // Divide Two Negative Numbers
    assert_eq(
        negative_from(123).div(negative_from(3)),
        from_u32(41),
    );

    // Divide Negative by Positive
    assert_eq(
        negative_from(123).div(from_u32(3)),
        negative_from(41),
    );

    // Divide Positive by Negative
    assert_eq(
        from_u32(123).div(negative_from(3)),
        negative_from(41),
    );

    // Divide Maximum by 2
    assert_eq(i32::max().div(from_u32(2)), from_u32(1073741823));

    // Divide Minimum by 2
    assert_eq(
        i32::min().div(from_u32(2)),
        negative_from(1073741824),
    );

    // Round towards zero
    assert_eq(from_u32(123).div(from_u32(10)), from_u32(12));
    assert_eq(
        negative_from(123).div(from_u32(10)),
        negative_from(12),
    );
}

#[test, expected_failure(abort_code = i32::EDivByZero, location = i32)]
fun test_div_by_zero() {
    from_u32(123).div(from_u32(0));
}

#[test]
fun test_ceil_div() {
    // Basic Positive Even Division
    assert_eq(from_u32(10).div_up(from_u32(2)), from_u32(5));

    // Basic Positive Division Round Up
    assert_eq(from_u32(11).div_up(from_u32(2)), from_u32(6));
    // Division of zero
    assert_eq(from_u32(0).div(from_u32(123)), from_u32(0));

    // Divide Two Negative Numbers
    assert_eq(
        negative_from(123).div(negative_from(3)),
        from_u32(41),
    );

    // Divide Negative by Positive
    assert_eq(
        negative_from(123).div(from_u32(3)),
        negative_from(41),
    );

    // Divide Positive by Negative
    assert_eq(
        from_u32(123).div(negative_from(3)),
        negative_from(41),
    );

    // Divide Maximum by 2
    assert_eq(i32::max().div(from_u32(2)), from_u32(1073741823));

    // Divide Minimum by 2
    assert_eq(
        i32::min().div(from_u32(2)),
        negative_from(1073741824),
    );
}

#[test, expected_failure(abort_code = i32::EDivByZero, location = i32)]
fun test_ceil_div_by_zero() {
    from_u32(123).div_up(from_u32(0));
}

#[test]
fun test_wrapping_add() {
    // Basic positive number addition
    assert_eq(from_u32(5).wrapping_add(from_u32(3)), from_u32(8));

    // Adding Zero
    assert_eq(from_u32(42).wrapping_add(from_u32(0)), from_u32(42));

    // Negative number (in two's complement)
    assert_eq(
        negative_from(2).wrapping_add(negative_from(3)),
        negative_from(5),
    );

    // Mixed positive and negative numbers
    assert_eq(
        from_u32(10).wrapping_add(negative_from(15)),
        negative_from(5),
    );
    assert_eq(
        negative_from(10).wrapping_add(from_u32(15)),
        from_u32(5),
    );

    // Maximum overflow
    assert_eq(i32::max().wrapping_add(from_u32(1)), i32::min());
    assert_eq(
        i32::max().wrapping_add(from_u32(5)),
        i32::min().wrapping_add(from_u32(4)),
    );

    // Minimum underflow
    assert_eq(
        i32::min().wrapping_add(negative_from(1)),
        i32::max(),
    );
    assert_eq(
        i32::min().wrapping_add(negative_from(5)),
        i32::max().wrapping_add(negative_from(4)),
    );

    // Maximum + Maximum
    assert_eq(
        i32::max().wrapping_add(i32::max()),
        negative_from(2),
    );

    // Minimum + Minimum
    assert_eq(i32::min().wrapping_add(i32::min()), from_u32(0));

    // Any number - 1 should decrement the number
    assert_eq(
        from_u32(123).wrapping_add(negative_from(1)),
        from_u32(122),
    );

    // Zero + Any number should be the same number
    assert_eq(from_u32(123).wrapping_add(from_u32(0)), from_u32(123));
}

#[test]
fun test_wrapping_sub() {
    // Basic positive subtraction
    assert_eq(from_u32(8).wrapping_sub(from_u32(3)), from_u32(5));

    // Subtracting zero
    assert_eq(from_u32(8).wrapping_sub(from_u32(0)), from_u32(8));
    assert_eq(
        from_u32(0).wrapping_sub(from_u32(8)),
        negative_from(8),
    );
    assert_eq(from_u32(0).wrapping_sub(from_u32(0)), from_u32(0));
    assert_eq(
        negative_from(0).wrapping_sub(from_u32(0)),
        negative_from(0),
    );

    // Subtracting a negative number
    assert_eq(
        negative_from(5).wrapping_sub(negative_from(3)),
        negative_from(2),
    );

    // Positive and negative subtraction
    assert_eq(
        from_u32(5).wrapping_sub(negative_from(3)),
        from_u32(8),
    );
    assert_eq(
        negative_from(5).wrapping_sub(from_u32(3)),
        negative_from(8),
    );

    // Subtracting a larger number
    assert_eq(
        from_u32(8).wrapping_sub(from_u32(11)),
        negative_from(3),
    );

    // Subtracting a negative number from_u32 a positive number
    assert_eq(
        negative_from(5).wrapping_sub(from_u32(3)),
        negative_from(8),
    );

    // Minimum + Max
    assert_eq(i32::max().wrapping_sub(i32::max()), from_u32(0));

    assert_eq(
        i32::max().wrapping_sub(i32::max()).wrapping_sub(i32::max()),
        i32::min().add(from_u32(1)),
    );

    assert_eq(
        i32::max().wrapping_sub(negative_from(1)),
        i32::min(),
    );
    assert_eq(i32::min().wrapping_sub(from_u32(1)), i32::max());
}

#[test]
fun test_mod() {
    // Basic Positive Modulo
    assert_eq(from_u32(10).mod(from_u32(3)), from_u32(1));

    // Modulo of zero
    assert_eq(from_u32(0).mod(from_u32(123)), from_u32(0));

    // Modulo of negative number
    assert_eq(
        negative_from(10).mod(from_u32(3)),
        negative_from(1),
    );

    // Modulo of negative number
    assert_eq(from_u32(10).mod(negative_from(3)), from_u32(1));

    // Modulo of negative number
    assert_eq(
        negative_from(10).mod(negative_from(3)),
        negative_from(1),
    );

    // Modulo of maximum
    assert_eq(i32::max().mod(from_u32(1)), from_u32(0));
    assert_eq(i32::max().mod(from_u32(2)), from_u32(1));

    // Modulo of minimum
    assert_eq(i32::min().mod(from_u32(2)), from_u32(0));
    assert_eq(i32::min().mod(from_u32(1)), from_u32(0));
}

#[test, expected_failure(abort_code = i32::EDivByZero, location = i32)]
fun test_mod_by_zero() {
    from_u32(123).mod(from_u32(0));
}

#[test]
fun test_pow() {
    // Basic Positive Power
    assert_eq(from_u32(2).pow(3), from_u32(8));
    assert_eq(from_u32(2).pow(4), from_u32(16));

    // Power of Zero
    assert_eq(from_u32(2).pow(0), from_u32(1));
    assert_eq(negative_from(2).pow(0), from_u32(1));
    assert_eq(from_u32(0).pow(0), from_u32(1));
    assert_eq(from_u32(0).pow(1), from_u32(0));
    assert_eq(from_u32(0).pow(3), from_u32(0));

    // Power of 1
    assert_eq(from_u32(2).pow(1), from_u32(2));
    assert_eq(from_u32(1).pow(112345), from_u32(1));

    // Negative Base
    assert_eq(negative_from(2).pow(3), negative_from(8));
    assert_eq(negative_from(2).pow(0), from_u32(1));
    assert_eq(negative_from(2).pow(1), negative_from(2));
    assert_eq(negative_from(2).pow(4), from_u32(16));
    assert_eq(negative_from(2).pow(3), negative_from(8));
}

#[test]
fun test_and() {
    // Basic Positive And
    assert_eq(from_u32(10).and(from_u32(3)), from_u32(2));

    // And with zero
    assert_eq(from_u32(10).and(from_u32(0)), from_u32(0));
    assert_eq(from_u32(0).and(from_u32(10)), from_u32(0));

    // All bits set
    assert_eq(i32::max().and(i32::max()), i32::max());
    assert_eq(i32::max().and(from_u32(5)), from_u32(5));

    // All bits unset
    assert_eq(i32::min().and(i32::min()), i32::min());
    assert_eq(i32::min().and(from_u32(5)), from_u32(0));

    // Negative number (testing sign bit )
    assert_eq(
        negative_from(1).and(negative_from(2)),
        negative_from(2),
    );

    // Testing Max and Min
    assert_eq(i32::max().and(i32::min()), from_u32(0));

    // Common Bit pattern
    assert_eq(from_u32(0xFF).and(from_u32(0xFF00000)), from_u32(0));
}

#[test]
fun test_or() {
    // Basic Positive Case
    assert_eq(from_u32(5).or(from_u32(3)), from_u32(7));

    // Or with zero
    assert_eq(from_u32(5).or(from_u32(0)), from_u32(5));
    assert_eq(from_u32(0).or(from_u32(5)), from_u32(5));
    assert_eq(from_u32(0).or(from_u32(0)), from_u32(0));

    // All bits set
    assert_eq(i32::max().or(i32::max()), i32::max());
    assert_eq(i32::max().or(from_u32(5)), i32::max());

    // All bits unset
    assert_eq(i32::min().or(i32::min()), i32::min());
    assert_eq(
        i32::min().or(from_u32(5)),
        from_u32(5).add(i32::min()),
    );

    // Negative number (testing sign bit )
    assert_eq(
        negative_from(1).or(negative_from(2)),
        negative_from(1),
    );

    // Testing Max and Min
    assert_eq(i32::max().or(i32::max()), i32::max());
    assert_eq(i32::min().or(i32::min()), i32::min());
    assert_eq(i32::max().or(i32::min()), negative_from(1));

    // Common Bit pattern
    assert_eq(
        from_u32(0xFF).or(from_u32(0xFF00000)).value(),
        0xFF000FF,
    );
}

#[test]
fun test_xor() {
    // Basic Positive Case
    assert_eq(from_u32(5).xor(from_u32(3)), from_u32(6));

    // Xor with zero
    assert_eq(from_u32(5).xor(from_u32(0)), from_u32(5));
    assert_eq(from_u32(0).xor(from_u32(5)), from_u32(5));
    assert_eq(from_u32(0).xor(from_u32(0)), from_u32(0));

    // All bits set
    assert_eq(i32::max().xor(i32::max()), from_u32(0));
    assert_eq(i32::max().xor(from_u32(5)).value(), 0x7FFFFFFA);

    // All bits unset
    assert_eq(i32::min().xor(i32::min()), from_u32(0));
    assert_eq(
        i32::min().xor(from_u32(5)),
        from_u32(5).add(i32::min()),
    );

    // Xor with self
    assert_eq(from_u32(5).xor(from_u32(5)), from_u32(0));

    // Negative number (testing sign bit )
    assert_eq(
        negative_from(1).xor(negative_from(2)),
        from_u32(1),
    );

    // Testing Max and Min
    assert_eq(i32::max().xor(i32::min()), negative_from(1));

    // Common Bit pattern
    assert_eq(
        from_u32(0xFF).or(from_u32(0xFF00000)).value(),
        0xFF000FF,
    );
}

#[test]
fun test_not() {
    // Basic Positive Case
    assert_eq(from_u32(5).not(), negative_from(6));

    // Not with zero
    assert_eq(from_u32(0).not(), negative_from(1));

    // All bits set
    assert_eq(i32::max().not(), i32::min());

    // All bits unset
    assert_eq(i32::min().not(), i32::max());

    // All ones (-1)
    assert_eq(negative_from(1).not(), from_u32(0));

    assert_eq(negative_from(2).not(), from_u32(1));

    // Common Bit pattern
    assert_eq(from_u32(0xFF).not().value(), 0xFFFFFF00);

    // Common numbers
    assert_eq(from_u32(0x12345678).not().value(), 0xEDCBA987);
}

#[test]
fun test_shr() {
    assert_eq(negative_from(10).shr(1), negative_from(5));
    assert_eq(negative_from(25).shr(3), negative_from(4));
    assert_eq(
        negative_from(2147483648).shr(1),
        negative_from(1073741824),
    );
    assert_eq(
        negative_from(123456789).shr(31),
        negative_from(1),
    );
    assert_eq(
        negative_from(987654321).shr(31),
        negative_from(1),
    );
    assert_eq(negative_from(42).shr(31), negative_from(1));
    assert_eq(negative_from(0).shr(31), negative_from(0));
    assert_eq(from_u32(0).shr(20), from_u32(0));
}

#[test]
fun test_shl() {
    // Basic Positive Case
    assert_eq(from_u32(1).shl(1), from_u32(2));
    assert_eq(from_u32(1).shl(2), from_u32(4));

    // Shift with multiple bit sets
    assert_eq(from_u32(5).shl(1), from_u32(10));
    assert_eq(from_u32(5).shl(2), from_u32(20));

    // Shift Zero
    assert_eq(from_u32(0).shl(1), from_u32(0));
    assert_eq(from_u32(0).shl(31), from_u32(0));

    // Negative number
    assert_eq(negative_from(1).shl(1), negative_from(2));
    assert_eq(negative_from(1).shl(2), negative_from(4));

    // Edge Cases Max and Min
    assert_eq(i32::max().shl(1), negative_from(2));
    assert_eq(i32::min().shl(1), from_u32(0));

    // Maximum valid shift
    assert_eq(from_u32(1).shl(30).value(), 0x40000000);
    assert_eq(from_u32(1).shl(31), i32::min());

    // Boundary shifts do not overflow
    assert_eq(from_u32(0xFF).shl(24).value(), 0xFF000000);
}

#[test, expected_failure(abort_code = i32::EInvalidBitShift, location = i32)]
fun test_shl_overflow() {
    from_u32(1).shl(32);
}

#[test, expected_failure(abort_code = i32::EInvalidBitShift, location = i32)]
fun test_shr_overflow() {
    from_u32(1).shr(32);
}
