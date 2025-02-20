module interest_math::i32;

use interest_math::{int_macro as macro, uint_macro};

// === Constants ===

const MAX_U32: u32 = 0xFFFFFFFF;

const MAX_POSITIVE: u32 = 0x7FFFFFFF;

const MIN_NEGATIVE: u32 = 0x80000000;

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

public struct I32 has copy, drop, store {
    value: u32,
}

// === Public Functions ===

public fun value(self: I32): u32 {
    macro::value!(self)
}

public fun zero(): I32 {
    I32 { value: 0 }
}

public fun max(): I32 {
    I32 { value: MAX_POSITIVE }
}

public fun min(): I32 {
    I32 { value: MIN_NEGATIVE }
}

public fun from_u32(value: u32): I32 {
    I32 { value: check_overflow_and_return(value) }
}

public fun from_u64(value: u64): I32 {
    I32 { value: check_overflow_and_return(value as u32) }
}

public fun from_u128(value: u128): I32 {
    I32 { value: check_overflow_and_return(value as u32) }
}

public fun negative_from_u32(value: u32): I32 {
    negative_from_u64(value as u64)
}

public fun negative_from_u64(value: u64): I32 {
    if (value == 0) return zero();

    I32 {
        value: not_u32(check_underflow_and_return(value as u32)) + 1 | MIN_NEGATIVE,
    }
}

public fun negative_from_u128(value: u128): I32 {
    negative_from_u64(value as u64)
}

public fun to_u32(self: I32): u32 {
    self.check_is_positive_and_return_value()
}

public fun to_u64(self: I32): u64 {
    self.check_is_positive_and_return_value() as u64
}

public fun to_u128(self: I32): u128 {
    self.check_is_positive_and_return_value() as u128
}

public fun truncate_to_u8(self: I32): u8 {
    ((self.value & 0xFF) as u8)
}

public fun truncate_to_u16(self: I32): u16 {
    ((self.value & 0xFFFF) as u16)
}

public fun is_negative(self: I32): bool {
    macro::is_negative!(self, MIN_NEGATIVE)
}

public fun is_positive(self: I32): bool {
    macro::is_positive!(self, MIN_NEGATIVE)
}

public fun is_zero(self: I32): bool {
    self.value == 0
}

public fun abs(self: I32): I32 {
    if (self.is_negative()) {
        assert!(self.value > MIN_NEGATIVE, EUnderflow);
        I32 { value: not_u32(self.value - 1) }
    } else {
        self
    }
}

public fun eq(self: I32, other: I32): bool {
    self.compare(other) == Compare::Equal
}

public fun lt(self: I32, other: I32): bool {
    self.compare(other) == Compare::Less
}

public fun gt(self: I32, other: I32): bool {
    self.compare(other) == Compare::Greater
}

public fun lte(self: I32, other: I32): bool {
    let pred = self.compare(other);
    pred == Compare::Less || pred == Compare::Equal
}

public fun gte(self: I32, other: I32): bool {
    let pred = self.compare(other);
    pred == Compare::Greater || pred == Compare::Equal
}

public fun add(self: I32, other: I32): I32 {
    macro::add!(self, other, EOverflow)
}

public fun sub(self: I32, other: I32): I32 {
    self.add(I32 { value: not_u32(other.value) }.wrapping_add(from_u32(1)))
}

public fun mul(self: I32, other: I32): I32 {
    if (self.value == 0 || other.value == 0) return zero();

    if (self.is_positive() != other.is_positive()) {
        negative_from_u32(self.abs_unchecked_u32() * other.abs_unchecked_u32())
    } else {
        from_u32(self.abs_unchecked_u32() * other.abs_unchecked_u32())
    }
}

// @dev div is the same as floor_div
public fun div(self: I32, other: I32): I32 {
    assert!(other.value != 0, EDivByZero);

    if (self.is_positive() != other.is_positive()) {
        negative_from_u32(self.abs_unchecked_u32() / other.abs_unchecked_u32())
    } else {
        from_u32(self.abs_unchecked_u32() / other.abs_unchecked_u32())
    }
}

public fun div_up(self: I32, other: I32): I32 {
    assert!(other.value != 0, EDivByZero);

    if (self.is_positive() != other.is_positive()) {
        negative_from_u32(
            uint_macro::div_up!(self.abs_unchecked_u32(), other.abs_unchecked_u32()),
        )
    } else {
        from_u32(
            uint_macro::div_up!(self.abs_unchecked_u32(), other.abs_unchecked_u32()),
        )
    }
}

public fun mod(self: I32, other: I32): I32 {
    assert!(other.value != 0, EDivByZero);

    let other_abs = other.abs_unchecked_u32();

    if (self.is_negative()) {
        negative_from_u32(self.abs_unchecked_u32() % other_abs)
    } else {
        from_u32(self.value % other_abs)
    }
}

public fun pow(self: I32, exponent: u32): I32 {
    let result = uint_macro::pow!<u32>(self.abs().value as u64, exponent);

    if (self.is_negative() && exponent % 2 != 0) negative_from_u32(result)
    else from_u32(result)
}

public fun wrapping_add(self: I32, other: I32): I32 {
    I32 {
        value: if (self.value > (MAX_U32 - other.value)) {
            self.value - (MAX_U32 - other.value) - 1
        } else {
            self.value + other.value
        },
    }
}

public fun wrapping_sub(self: I32, other: I32): I32 {
    self.wrapping_add(I32 { value: not_u32(other.value) }.wrapping_add(from_u32(1)))
}

public fun and(self: I32, other: I32): I32 {
    I32 { value: self.value & other.value }
}

public fun or(self: I32, other: I32): I32 {
    I32 { value: self.value | other.value }
}

public fun xor(self: I32, other: I32): I32 {
    I32 { value: self.value ^ other.value }
}

public fun not(self: I32): I32 {
    I32 { value: not_u32(self.value) }
}

public fun shr(self: I32, rhs: u8): I32 {
    assert!(rhs < 32, EInvalidBitShift);

    if (rhs == 0) return self;

    if (self.is_positive()) {
        I32 { value: self.value >> rhs }
    } else {
        I32 { value: self.value >> rhs | MAX_U32 << (32 - rhs) }
    }
}

public fun shl(self: I32, lhs: u8): I32 {
    assert!(lhs < 32, EInvalidBitShift);

    I32 { value: self.value << lhs }
}

// === Private Functions ===

fun abs_unchecked_u32(self: I32): u32 {
    if (self.is_positive()) {
        self.value
    } else {
        not_u32(self.value - 1)
    }
}

fun compare(self: I32, other: I32): Compare {
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

fun sign(self: I32): u8 {
    (self.value >> 31) as u8
}

fun not_u32(value: u32): u32 {
    value ^ MAX_U32
}

fun check_is_positive_and_return_value(self: I32): u32 {
    assert!(self.is_positive(), EUnderflow);
    self.value
}

fun check_overflow(value: u32) {
    assert!(MAX_POSITIVE >= value, EOverflow);
}

fun check_underflow(value: u32) {
    assert!(MIN_NEGATIVE >= value, EUnderflow);
}

fun check_overflow_and_return(value: u32): u32 {
    check_overflow(value);
    value
}

fun check_underflow_and_return(value: u32): u32 {
    check_underflow(value);
    value
}
