#[test_only]
module interest_math::i256_tests;

use interest_math::{
    i256::{
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
        from_u256,
        is_positive,
        negative_from_u256,
        truncate_to_u8,
        truncate_to_u16,
        truncate_to_u32,
        truncate_to_u64,
        truncate_to_u128,
        I256
    },
    u256
};
use sui::test_utils::assert_eq;

const POW_18: u256 = 1_000_000_000_000_000_000;

#[test]
fun test_simple_functions() {
    assert_eq(value(one()), 1);
    assert_eq(is_zero(zero()), true);
    assert_eq(is_zero(one()), false);
    assert_eq(is_zero(negative_from_u256(1)), false);
}

#[test]
fun test_compare_functions() {
    assert_eq(eq(zero(), zero()), true);
    assert_eq(eq(zero(), one()), false);
    assert_eq(eq(negative_from_u256(2), from_u256(2)), false);

    assert_eq(lt(negative_from_u256(2), negative_from_u256(1)), true);
    assert_eq(lt(negative_from_u256(1), negative_from_u256(2)), false);
    assert_eq(lt(from_u256(2), from_u256(1)), false);
    assert_eq(lt(from_u256(1), from_u256(2)), true);
    assert_eq(lt(from_u256(2), from_u256(2)), false);

    assert_eq(lte(negative_from_u256(2), negative_from_u256(1)), true);
    assert_eq(lte(negative_from_u256(1), negative_from_u256(2)), false);
    assert_eq(lte(from_u256(2), from_u256(1)), false);
    assert_eq(lte(from_u256(1), from_u256(2)), true);
    assert_eq(lte(from_u256(2), from_u256(2)), true);

    assert_eq(gt(negative_from_u256(2), negative_from_u256(1)), false);
    assert_eq(gt(negative_from_u256(1), negative_from_u256(2)), true);
    assert_eq(gt(from_u256(2), from_u256(1)), true);
    assert_eq(gt(from_u256(1), from_u256(2)), false);
    assert_eq(gt(from_u256(2), from_u256(2)), false);

    assert_eq(gte(negative_from_u256(2), negative_from_u256(1)), false);
    assert_eq(gte(negative_from_u256(1), negative_from_u256(2)), true);
    assert_eq(gte(from_u256(2), from_u256(1)), true);
    assert_eq(gte(from_u256(1), from_u256(2)), false);
    assert_eq(gte(from_u256(2), from_u256(2)), true);
}

#[test]
fun test_truncate_to_u8() {
    assert_eq(truncate_to_u8(from_u256(0x1234567890)), 0x90);
    assert_eq(truncate_to_u8(from_u256(0xABCDEF)), 0xEF);
    assert_eq(
        truncate_to_u8(
            from_u256(0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        ),
        255,
    );
    assert_eq(truncate_to_u8(from_u256(256)), 0);
    assert_eq(truncate_to_u8(from_u256(511)), 255);
    assert_eq(truncate_to_u8(negative_from_u256(230)), 26);
}

#[test]
fun test_truncate_to_u16() {
    assert_eq(truncate_to_u16(from_u256(0)), 0);
    assert_eq(truncate_to_u16(from_u256(65535)), 65535);
    assert_eq(truncate_to_u16(from_u256(65536)), 0);
    assert_eq(truncate_to_u16(negative_from_u256(32768)), 32768);
    assert_eq(
        truncate_to_u16(
            from_u256(0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
        ),
        65535,
    );
    assert_eq(truncate_to_u16(from_u256(12345)), 12345);
    assert_eq(truncate_to_u16(negative_from_u256(9876)), 55660);
    assert_eq(
        truncate_to_u16(
            from_u256(
                1766847064778384329583297500742918515827483896875618958121606201292619776,
            ),
        ),
        0,
    );
    assert_eq(truncate_to_u16(from_u256(32768)), 32768);
    assert_eq(truncate_to_u16(from_u256(50000)), 50000);
}

#[test]
fun test_truncate_to_u32() {
    assert_eq(truncate_to_u32(negative_from_u256(2147483648)), 2147483648);
    assert_eq(truncate_to_u32(from_u256(4294967295)), 4294967295);
    assert_eq(truncate_to_u32(from_u256(4294967296)), 0);
    assert_eq(truncate_to_u32(negative_from_u256(123456789)), 4171510507);
    assert_eq(truncate_to_u32(from_u256(987654321)), 987654321);
    assert_eq(truncate_to_u32(negative_from_u256(876543210)), 3418424086);
    assert_eq(truncate_to_u32(from_u256(2147483648)), 2147483648);
    assert_eq(truncate_to_u32(negative_from_u256(2147483648)), 2147483648);
    assert_eq(truncate_to_u32(from_u256(1073741824)), 1073741824);
    assert_eq(truncate_to_u32(from_u256(305419896)), 305419896);
}

#[test]
fun test_truncate_to_u64() {
    assert_eq(truncate_to_u64(from_u256(0xFFFFFFFFFFFFFFFF)), 18446744073709551615);
    assert_eq(truncate_to_u64(from_u256(0x00000000FFFFFFFF)), 4294967295);
    assert_eq(truncate_to_u64(from_u256(0xFFFFFFFF00000000)), 18446744069414584320);
    assert_eq(truncate_to_u64(from_u256(0xAAAAAAAAAAAAAAAA)), 12297829382473034410);
    assert_eq(truncate_to_u64(from_u256(0x0000000000000000)), 0x00000000);
    assert_eq(truncate_to_u64(from_u256(18446744073709551615)), 18446744073709551615);
    assert_eq(truncate_to_u64(from_u256(18446744073709551616)), 0);
    assert_eq(truncate_to_u64(from_u256(12345678901234567890)), 12345678901234567890);
    assert_eq(truncate_to_u64(negative_from_u256(789012)), 18446744073708762604);
    assert_eq(truncate_to_u64(negative_from_u256(9223372036854775808)), 9223372036854775808);
    assert_eq(truncate_to_u64(negative_from_u256(9223372036854775807)), 9223372036854775809);
    assert_eq(truncate_to_u64(negative_from_u256(123456789)), 18446744073586094827);
}

#[test]
fun test_truncate_to_u128() {
    assert_eq(
        truncate_to_u128(from_u256(123456789012345678901234567890)),
        123456789012345678901234567890,
    );
    assert_eq(
        truncate_to_u128(negative_from_u256(987654321098765432109876543210)),
        340282365933284142364609175321891668246,
    );
    assert_eq(truncate_to_u128(from_u256(0)), 0);
    assert_eq(
        truncate_to_u128(from_u256(170141183460469231731687303715884105727)),
        170141183460469231731687303715884105727,
    );
    assert_eq(
        truncate_to_u128(from_u256(987654321098765432109876543210)),
        987654321098765432109876543210,
    );
    assert_eq(
        truncate_to_u128(negative_from_u256(123456789012345678901234567890)),
        340282366797481674451028928530533643566,
    );
    assert_eq(
        truncate_to_u128(negative_from_u256(170141183460469231731687303715884105728)),
        170141183460469231731687303715884105728,
    );
}

#[test]
fun test_compare() {
    assert_eq(eq(from_u256(123), from_u256(123)), true);
    assert_eq(eq(negative_from_u256(123), negative_from_u256(123)), true);
    assert_eq(eq(from_u256(234), from_u256(123)), false);
    assert_eq(lt(from_u256(123), from_u256(234)), true);
    assert_eq(lt(negative_from_u256(234), negative_from_u256(123)), true);
    assert_eq(gt(negative_from_u256(123), negative_from_u256(234)), true);
    assert_eq(gt(from_u256(123), negative_from_u256(234)), true);
    assert_eq(lt(negative_from_u256(123), from_u256(234)), true);
    assert_eq(gt(from_u256(234), negative_from_u256(123)), true);
    assert_eq(lt(negative_from_u256(234), from_u256(123)), true);
}

#[test]
fun test_add() {
    assert_eq(add(from_u256(123), from_u256(234)), from_u256(357));
    assert_eq(add(from_u256(123), negative_from_u256(234)), negative_from_u256(111));
    assert_eq(add(from_u256(234), negative_from_u256(123)), from_u256(111));
    assert_eq(add(negative_from_u256(123), from_u256(234)), from_u256(111));
    assert_eq(add(negative_from_u256(123), negative_from_u256(234)), negative_from_u256(357));
    assert_eq(add(negative_from_u256(234), negative_from_u256(123)), negative_from_u256(357));
    assert_eq(add(from_u256(123), negative_from_u256(123)), zero());
    assert_eq(add(negative_from_u256(123), from_u256(123)), zero());
}

#[test]
fun test_sub() {
    assert_eq(sub(from_u256(123), from_u256(234)), negative_from_u256(111));
    assert_eq(sub(from_u256(234), from_u256(123)), from_u256(111));
    assert_eq(sub(from_u256(123), negative_from_u256(234)), from_u256(357));
    assert_eq(sub(negative_from_u256(123), from_u256(234)), negative_from_u256(357));
    assert_eq(sub(negative_from_u256(123), negative_from_u256(234)), from_u256(111));
    assert_eq(sub(negative_from_u256(234), negative_from_u256(123)), negative_from_u256(111));
    assert_eq(sub(from_u256(123), from_u256(123)), zero());
    assert_eq(sub(negative_from_u256(123), negative_from_u256(123)), zero());
}

#[test]
fun test_mul() {
    assert_eq(mul(from_u256(123), from_u256(234)), from_u256(28782));
    assert_eq(mul(from_u256(123), negative_from_u256(234)), negative_from_u256(28782));
    assert_eq(mul(negative_from_u256(123), from_u256(234)), negative_from_u256(28782));
    assert_eq(mul(negative_from_u256(123), negative_from_u256(234)), from_u256(28782));
}

#[test]
fun test_div_down() {
    assert_eq(div(from_u256(28781), from_u256(123)), from_u256(233));
    assert_eq(div(from_u256(28781), negative_from_u256(123)), negative_from_u256(233));
    assert_eq(div(negative_from_u256(28781), from_u256(123)), negative_from_u256(233));
    assert_eq(div(negative_from_u256(28781), negative_from_u256(123)), from_u256(233));
}

#[test]
fun test_div_up() {
    assert_eq(div_up(from_u256(512), from_u256(256)), from_u256(2));
    assert_eq(div_up(from_u256(768), from_u256(256)), from_u256(3));
    assert_eq(div_up(negative_from_u256(512), from_u256(256)), negative_from_u256(2));
    assert_eq(div_up(negative_from_u256(768), from_u256(256)), negative_from_u256(3));
    assert_eq(div_up(from_u256(12345), from_u256(1)), from_u256(12345));
    assert_eq(div_up(from_u256(0), from_u256(256)), from_u256(0));
    assert_eq(div_up(from_u256(701), from_u256(200)), from_u256(4));
    assert_eq(div_up(from_u256(701), negative_from_u256(200)), negative_from_u256(4));
}

#[test]
fun test_shl() {
    assert_eq(eq(shl(from_u256(42), 0), from_u256(42)), true);
    assert_eq(eq(shl(from_u256(42), 1), from_u256(84)), true);
    assert_eq(eq(shl(negative_from_u256(42), 2), negative_from_u256(168)), true);
    assert_eq(eq(shl(zero(), 5), zero()), true);
    assert_eq(eq(shl(from_u256(42), 255), zero()), true);
    assert_eq(eq(shl(from_u256(5), 3), from_u256(40)), true);
    assert_eq(eq(shl(negative_from_u256(5), 3), negative_from_u256(40)), true);
    assert_eq(eq(shl(negative_from_u256(123456789), 5), negative_from_u256(3950617248)), true);
}

#[test]
fun test_abs() {
    assert_eq(value(from_u256(10)), value(abs(negative_from_u256(10))));
    assert_eq(value(from_u256(12826189)), value(abs(negative_from_u256(12826189))));
    assert_eq(value(from_u256(10)), value(abs(from_u256(10))));
    assert_eq(value(from_u256(12826189)), value(abs(from_u256(12826189))));
    assert_eq(value(from_u256(0)), value(abs(from_u256(0))));
}

#[test]
fun test_pow() {
    assert_eq(pow(from_u256(0), 0), one());
    assert_eq(pow(from_u256(0), 1), zero());
    assert_eq(pow(from_u256(0), 112345), zero());
    assert_eq(pow(from_u256(1), 112345), one());
    assert_eq(pow(from_u256(1), 0), one());
    assert_eq(pow(from_u256(12345), 1), from_u256(12345));
    assert_eq(pow(from_u256(2), 3), from_u256(8));
    assert_eq(pow(negative_from_u256(2), 3), negative_from_u256(8));
    assert_eq(pow(from_u256(2), 4), from_u256(16));
    assert_eq(pow(negative_from_u256(2), 4), from_u256(16));
}

#[test]
fun test_neg_from() {
    assert_eq(
        value(negative_from_u256(10)),
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF6,
    );
    assert_eq(
        value(negative_from_u256(100)),
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF9C,
    );
}

#[test]
fun test_shr() {
    assert_eq(shr(negative_from_u256(10), 1), negative_from_u256(5));
    assert_eq(shr(negative_from_u256(25), 3), negative_from_u256(4));
    assert_eq(shr(negative_from_u256(2147483648), 1), negative_from_u256(1073741824));
    assert_eq(shr(negative_from_u256(123456789), 32), negative_from_u256(1));
    assert_eq(shr(negative_from_u256(987654321), 40), negative_from_u256(1));
    assert_eq(shr(negative_from_u256(42), 100), negative_from_u256(1));
    assert_eq(shr(negative_from_u256(0), 100), negative_from_u256(0));
    assert_eq(shr(from_u256(0), 20), from_u256(0));
}

#[test]
fun test_or() {
    assert_eq(or(zero(), zero()), zero());
    assert_eq(or(zero(), negative_from_u256(1)), negative_from_u256(1));
    assert_eq(or(negative_from_u256(1), negative_from_u256(1)), negative_from_u256(1));
    assert_eq(or(negative_from_u256(1), from_u256(1)), negative_from_u256(1));
    assert_eq(or(from_u256(10), from_u256(5)), from_u256(15));
    assert_eq(or(negative_from_u256(10), negative_from_u256(5)), negative_from_u256(1));
    assert_eq(or(negative_from_u256(10), negative_from_u256(4)), negative_from_u256(2));
}

#[test]
fun test_is_neg() {
    assert_eq(is_negative(zero()), false);
    assert_eq(is_negative(negative_from_u256(5)), true);
    assert_eq(is_negative(from_u256(172)), false);
}

#[test]
fun test_is_positive() {
    assert_eq(is_positive(zero()), true);
    assert_eq(is_positive(negative_from_u256(5)), false);
    assert_eq(is_positive(from_u256(172)), true);
}

#[test]
fun test_and() {
    assert_eq(and(zero(), zero()), zero());
    assert_eq(and(zero(), negative_from_u256(1)), zero());
    assert_eq(and(negative_from_u256(1), negative_from_u256(1)), negative_from_u256(1));
    assert_eq(and(negative_from_u256(1), from_u256(1)), from_u256(1));
    assert_eq(and(from_u256(10), from_u256(5)), zero());
    assert_eq(and(negative_from_u256(10), negative_from_u256(5)), negative_from_u256(14));
}

#[test]
fun test_mod() {
    assert_eq(mod(negative_from_u256(100), negative_from_u256(30)), negative_from_u256(10));
    assert_eq(mod(negative_from_u256(100), negative_from_u256(30)), negative_from_u256(10));
    assert_eq(mod(from_u256(100), negative_from_u256(30)), from_u256(10));
    assert_eq(mod(from_u256(100), from_u256(30)), from_u256(10));
    assert_eq(
        mod(from_u256(1234567890123456789012345678901234567890), from_u256(987654321)),
        from_u256(792341811),
    );
}

#[test]
fun test_wrapping_add() {
    // Basic positive number addition
    assert_eq(from_u256(5).wrapping_add(from_u256(3)), from_u256(8));

    // Adding Zero
    assert_eq(from_u256(42).wrapping_add(from_u256(0)), from_u256(42));

    // Negative number (in two's complement)
    assert_eq(
        negative_from_u256(2).wrapping_add(negative_from_u256(3)),
        negative_from_u256(5),
    );

    // Mixed positive and negative numbers
    assert_eq(
        from_u256(10).wrapping_add(negative_from_u256(15)),
        negative_from_u256(5),
    );
    assert_eq(
        negative_from_u256(10).wrapping_add(from_u256(15)),
        from_u256(5),
    );

    // Maximum overflow
    assert_eq(i256::max().wrapping_add(from_u256(1)), i256::min());
    assert_eq(
        i256::max().wrapping_add(from_u256(5)),
        i256::min().wrapping_add(from_u256(4)),
    );

    // Minimum underflow
    assert_eq(
        i256::min().wrapping_add(negative_from_u256(1)),
        i256::max(),
    );
    assert_eq(
        i256::min().wrapping_add(negative_from_u256(5)),
        i256::max().wrapping_add(negative_from_u256(4)),
    );

    // Maximum + Maximum
    assert_eq(
        i256::max().wrapping_add(i256::max()),
        negative_from_u256(2),
    );

    // Minimum + Minimum
    assert_eq(i256::min().wrapping_add(i256::min()), from_u256(0));

    // Any number - 1 should decrement the number
    assert_eq(
        from_u256(123).wrapping_add(negative_from_u256(1)),
        from_u256(122),
    );

    // Zero + Any number should be the same number
    assert_eq(from_u256(123).wrapping_add(from_u256(0)), from_u256(123));
}

#[test]
fun test_wrapping_sub() {
    // Basic positive subtraction
    assert_eq(from_u256(8).wrapping_sub(from_u256(3)), from_u256(5));

    // Subtracting zero
    assert_eq(from_u256(8).wrapping_sub(from_u256(0)), from_u256(8));
    assert_eq(
        from_u256(0).wrapping_sub(from_u256(8)),
        negative_from_u256(8),
    );
    assert_eq(from_u256(0).wrapping_sub(from_u256(0)), from_u256(0));
    assert_eq(
        negative_from_u256(0).wrapping_sub(from_u256(0)),
        negative_from_u256(0),
    );

    // Subtracting a negative number
    assert_eq(
        negative_from_u256(5).wrapping_sub(negative_from_u256(3)),
        negative_from_u256(2),
    );

    // Positive and negative subtraction
    assert_eq(
        from_u256(5).wrapping_sub(negative_from_u256(3)),
        from_u256(8),
    );
    assert_eq(
        negative_from_u256(5).wrapping_sub(from_u256(3)),
        negative_from_u256(8),
    );

    // Subtracting a larger number
    assert_eq(
        from_u256(8).wrapping_sub(from_u256(11)),
        negative_from_u256(3),
    );

    // Subtracting a negative number from_u32 a positive number
    assert_eq(
        negative_from_u256(5).wrapping_sub(from_u256(3)),
        negative_from_u256(8),
    );

    // Minimum + Max
    assert_eq(i256::max().wrapping_sub(i256::max()), from_u256(0));

    assert_eq(
        i256::max().wrapping_sub(i256::max()).wrapping_sub(i256::max()),
        i256::min().add(from_u256(1)),
    );

    assert_eq(
        i256::max().wrapping_sub(negative_from_u256(1)),
        i256::min(),
    );
    assert_eq(i256::min().wrapping_sub(from_u256(1)), i256::max());
}

#[test]
fun test_exp() {
    assert_eq(i256::negative_from_u256(42139678854452767551).exp().value(), 0);

    assert_eq(i256::negative_from_u256(3000000000000000000).exp().value(), 49787068367863942);
    assert_eq(i256::negative_from_u256(2 * POW_18).exp().value(), 135335283236612691);
    assert_eq(i256::negative_from_u256(POW_18).exp().value(), 367879441171442321);

    assert_eq(i256::negative_from_u256(5 * POW_18 / 10).exp().value(), 606530659712633423);
    assert_eq(i256::negative_from_u256(3 * POW_18 / 10).exp().value(), 740818220681717866);

    assert_eq(i256::from_u256(0).exp().value(), POW_18);

    assert_eq(i256::from_u256(3 * POW_18 / 10).exp().value(), 1349858807576003103);
    assert_eq(i256::from_u256(5 * POW_18 / 10).exp().value(), 1648721270700128146);

    assert_eq(i256::from_u256(1 * POW_18).exp().value(), 2718281828459045235);
    assert_eq(i256::from_u256(2 * POW_18).exp().value(), 7389056098930650227);
    assert_eq(i256::from_u256(3 * POW_18).exp().value(), 20085536923187667741);

    assert_eq(i256::from_u256(10 * POW_18).exp().value(), 220264657948067165169_80);

    assert_eq(
        i256::from_u256(50 * POW_18).exp().value(),
        5184705528587072464_148529318587763226117,
    );

    assert_eq(
        i256::from_u256(100 * POW_18).exp().value(),
        268811714181613544841_34666106240937146178367581647816351662017,
    );

    assert_eq(
        i256::from_u256(135305999368893231588).exp().value(),
        578960446186580976_50144101621524338577433870140581303254786265309376407432913,
    );
}

#[test]
fun test_ln() {
    assert_eq(i256::from_u256(POW_18).ln().value(), 0);
    assert_eq(i256::from_u256(2718281828459045235).ln().value(), 999999999999999999);
    assert_eq(i256::from_u256(11723640096265400935).ln().value(), 2461607324344817918);

    assert_eq(i256::from_u256(1).ln(), i256::negative_from_u256(41446531673892822313));
    assert_eq(i256::from_u256(42).ln(), i256::negative_from_u256(37708862055609454007));
    assert_eq(i256::from_u256(10000).ln(), i256::negative_from_u256(32236191301916639577));
    assert_eq(i256::from_u256(1000000000).ln(), i256::negative_from_u256(20723265836946411157));

    assert_eq(i256::from_u256(u256::pow(2, 255) - 1).ln().value(), 135305999368893231589);
    assert_eq(i256::from_u256(u256::pow(2, 170)).ln().value(), 76388489021297880288);
    assert_eq(i256::from_u256(u256::pow(2, 128)).ln().value(), 47276307437780177293);
}

#[test, expected_failure(abort_code = i256::EDivByZero, location = i256)]
fun test_mod_by_zero() {
    mod(from_u256(256), zero());
}

#[test]
#[expected_failure(abort_code = i256::EUndefined)]
fun test_negative_ln() {
    i256::negative_from_u256(1).ln();
}

#[test]
#[expected_failure(abort_code = i256::EUndefined)]
fun test_zero_ln() {
    i256::from_u256(0).ln();
}

#[test]
#[expected_failure(abort_code = i256::EOverflow)]
fun test_exp_overflow() {
    i256::from_u256(135305999368893231589).exp();
}

fun one(): I256 {
    from_u256(1)
}
