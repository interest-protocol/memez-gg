module interest_math::i64;

use interest_math::{int_macro as macro, uint_macro};

// === Constants ===

const MAX_U64: u64 = 0xFFFFFFFFFFFFFFFF;

const MAX_POSITIVE: u64 = 0x7FFFFFFFFFFFFFFF;

const MIN_NEGATIVE: u64 = 0x8000000000000000;

// === Errors ===

const EOverflow: u64 = 0;

const EUnderflow: u64 = 1;

const EDivByZero: u64 = 2;

const EInvalidBitShift: u64 = 3;

// === Structs ===

public enum Compare has copy, drop, store {
    Less,
    Equal,
    Greater,
}

public struct I64 has copy, drop, store {
    value: u64,
}

// === Public Functions ===

public fun value(self: I64): u64 {
    macro::value!(self)
}

public fun zero(): I64 {
    I64 { value: 0 }
}

public fun max(): I64 {
    I64 { value: MAX_POSITIVE }
}

public fun min(): I64 {
    I64 { value: MIN_NEGATIVE }
}

public fun from_u32(value: u32): I64 {
    I64 { value: value as u64 }
}

public fun from_u64(value: u64): I64 {
    I64 { value: check_overflow_and_return(value) }
}

public fun from_u128(value: u128): I64 {
    I64 { value: check_overflow_and_return(value as u64) }
}

public fun negative_from_u64(value: u64): I64 {
    if (value == 0) return zero();

    I64 {
        value: not_u64(check_underflow_and_return(value)) + 1 | MIN_NEGATIVE,
    }
}

public fun negative_from_u128(value: u128): I64 {
    negative_from_u64(value as u64)
}

public fun to_u64(self: I64): u64 {
    self.check_is_positive_and_return_value()
}

public fun to_u128(self: I64): u128 {
    self.check_is_positive_and_return_value() as u128
}

public fun truncate_to_u8(self: I64): u8 {
    ((self.value & 0xFF) as u8)
}

public fun truncate_to_u16(self: I64): u16 {
    ((self.value & 0xFFFF) as u16)
}

public fun truncate_to_u32(self: I64): u32 {
    ((self.value & 0xFFFFFFFF) as u32)
}

public fun is_negative(self: I64): bool {
    macro::is_negative!(self, MIN_NEGATIVE)
}

public fun is_positive(self: I64): bool {
    macro::is_positive!(self, MIN_NEGATIVE)
}

public fun is_zero(self: I64): bool {
    self.value == 0
}

public fun abs(self: I64): I64 {
    if (self.is_negative()) {
        assert!(self.value > MIN_NEGATIVE, EUnderflow);
        I64 { value: not_u64(self.value - 1) }
    } else {
        self
    }
}

public fun eq(self: I64, other: I64): bool {
    self.compare(other) == Compare::Equal
}

public fun lt(self: I64, other: I64): bool {
    self.compare(other) == Compare::Less
}

public fun gt(self: I64, other: I64): bool {
    self.compare(other) == Compare::Greater
}

public fun lte(self: I64, other: I64): bool {
    let pred = self.compare(other);
    pred == Compare::Less || pred == Compare::Equal
}

public fun gte(self: I64, other: I64): bool {
    let pred = self.compare(other);
    pred == Compare::Greater || pred == Compare::Equal
}

public fun add(self: I64, other: I64): I64 {
    macro::add!(self, other, EOverflow)
}

public fun sub(self: I64, other: I64): I64 {
    self.add(I64 { value: not_u64(other.value) }.wrapping_add(from_u64(1)))
}

public fun mul(self: I64, other: I64): I64 {
    if (self.value == 0 || other.value == 0) return zero();

    if (self.is_positive() != other.is_positive()) {
        negative_from_u64(self.abs_unchecked_u64() * other.abs_unchecked_u64())
    } else {
        from_u64(self.abs_unchecked_u64() * other.abs_unchecked_u64())
    }
}

public fun div(self: I64, other: I64): I64 {
    assert!(other.value != 0, EDivByZero);

    if (self.is_positive() != other.is_positive()) {
        negative_from_u64(self.abs_unchecked_u64() / other.abs_unchecked_u64())
    } else {
        from_u64(self.abs_unchecked_u64() / other.abs_unchecked_u64())
    }
}

public fun div_up(self: I64, other: I64): I64 {
    assert!(other.value != 0, EDivByZero);

    if (self.is_positive() != other.is_positive()) {
        negative_from_u64(
            uint_macro::div_up!(self.abs_unchecked_u64(), other.abs_unchecked_u64()),
        )
    } else {
        from_u64(
            uint_macro::div_up!(self.abs_unchecked_u64(), other.abs_unchecked_u64()),
        )
    }
}

public fun mod(self: I64, other: I64): I64 {
    assert!(other.value != 0, EDivByZero);

    let other_abs = other.abs_unchecked_u64();

    if (self.is_negative()) {
        negative_from_u64(self.abs_unchecked_u64() % other_abs)
    } else {
        from_u64(self.value % other_abs)
    }
}

public fun pow(self: I64, exponent: u64): I64 {
    let result = uint_macro::pow!<u64>(self.abs().value as u128, exponent);

    if (self.is_negative() && exponent % 2 != 0) negative_from_u64(result)
    else from_u64(result)
}

public fun wrapping_add(self: I64, other: I64): I64 {
    I64 {
        value: if (self.value > (MAX_U64 - other.value)) {
            self.value - (MAX_U64 - other.value) - 1
        } else {
            self.value + other.value
        },
    }
}

public fun wrapping_sub(self: I64, other: I64): I64 {
    self.wrapping_add(I64 { value: not_u64(other.value) }.wrapping_add(from_u64(1)))
}

public fun and(self: I64, other: I64): I64 {
    I64 { value: self.value & other.value }
}

public fun or(self: I64, other: I64): I64 {
    I64 { value: self.value | other.value }
}

public fun xor(self: I64, other: I64): I64 {
    I64 { value: self.value ^ other.value }
}

public fun not(self: I64): I64 {
    I64 { value: not_u64(self.value) }
}

public fun shr(self: I64, rhs: u8): I64 {
    assert!(rhs < 64, EInvalidBitShift);

    if (rhs == 0) return self;

    if (self.is_positive()) {
        I64 { value: self.value >> rhs }
    } else {
        I64 { value: self.value >> rhs | MAX_U64 << (64 - rhs) }
    }
}

public fun shl(self: I64, lhs: u8): I64 {
    assert!(lhs < 64, EInvalidBitShift);

    I64 { value: self.value << lhs }
}

// === Private Functions ===

fun abs_unchecked_u64(self: I64): u64 {
    if (self.is_positive()) {
        self.value
    } else {
        not_u64(self.value - 1)
    }
}

fun compare(self: I64, other: I64): Compare {
    if (self.value == other.value) return Compare::Equal;

    if (self.is_positive()) {
        if (other.is_positive()) {
            return if (self.value > other.value) Compare::Greater
            else Compare::Less
        } else {
            return Compare::Greater
        }
    } else {
        if (other.is_positive()) {
            return Compare::Less
        } else {
            return if (self.abs().value > other.abs().value) Compare::Less
            else Compare::Greater
        }
    }
}

fun sign(self: I64): u8 {
    (self.value >> 63) as u8
}

fun not_u64(value: u64): u64 {
    value ^ MAX_U64
}

fun check_is_positive_and_return_value(self: I64): u64 {
    assert!(self.is_positive(), EUnderflow);
    self.value
}

fun check_overflow(value: u64) {
    assert!(MAX_POSITIVE >= value, EOverflow);
}

fun check_underflow(value: u64) {
    assert!(MIN_NEGATIVE >= value, EUnderflow);
}

fun check_overflow_and_return(value: u64): u64 {
    check_overflow(value);
    value
}

fun check_underflow_and_return(value: u64): u64 {
    check_underflow(value);
    value
}
