module interest_math::i128;

use interest_math::{int_macro as macro, uint_macro};

// === Constants ===

const MAX_U128: u128 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

const MAX_POSITIVE: u128 = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

const MIN_NEGATIVE: u128 = 0x80000000000000000000000000000000;

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

public struct I128 has copy, drop, store {
    value: u128,
}

// === Public Functions ===

public fun value(self: I128): u128 {
    macro::value!(self)
}

public fun zero(): I128 {
    I128 { value: 0 }
}

public fun max(): I128 {
    I128 { value: MAX_POSITIVE }
}

public fun min(): I128 {
    I128 { value: MIN_NEGATIVE }
}

public fun from_u32(value: u32): I128 {
    I128 { value: value as u128 }
}

public fun from_u64(value: u64): I128 {
    I128 { value: value as u128 }
}

public fun from_u128(value: u128): I128 {
    I128 { value: check_overflow_and_return(value) }
}

public fun negative_from_u128(value: u128): I128 {
    if (value == 0) return zero();

    I128 {
        value: not_u128(check_underflow_and_return(value)) + 1 | MIN_NEGATIVE,
    }
}

public fun negative_from(value: u64): I128 {
    negative_from_u128(value as u128)
}

public fun to_u128(self: I128): u128 {
    self.check_is_positive_and_return_value()
}

public fun truncate_to_u8(self: I128): u8 {
    ((self.value & 0xFF) as u8)
}

public fun truncate_to_u16(self: I128): u16 {
    ((self.value & 0xFFFF) as u16)
}

public fun truncate_to_u32(self: I128): u32 {
    ((self.value & 0xFFFFFFFF) as u32)
}

public fun truncate_to_u64(self: I128): u64 {
    ((self.value & 0xFFFFFFFFFFFFFFFF) as u64)
}

public fun is_negative(self: I128): bool {
    macro::is_negative!(self, MIN_NEGATIVE)
}

public fun is_positive(self: I128): bool {
    macro::is_positive!(self, MIN_NEGATIVE)
}

public fun is_zero(self: I128): bool {
    self.value == 0
}

public fun abs(self: I128): I128 {
    if (self.is_negative()) {
        assert!(self.value > MIN_NEGATIVE, EUnderflow);
        I128 { value: not_u128(self.value - 1) }
    } else {
        self
    }
}

public fun eq(self: I128, other: I128): bool {
    self.compare(other) == Compare::Equal
}

public fun lt(self: I128, other: I128): bool {
    self.compare(other) == Compare::Less
}

public fun gt(self: I128, other: I128): bool {
    self.compare(other) == Compare::Greater
}

public fun lte(self: I128, other: I128): bool {
    let pred = self.compare(other);
    pred == Compare::Less || pred == Compare::Equal
}

public fun gte(self: I128, other: I128): bool {
    let pred = self.compare(other);
    pred == Compare::Greater || pred == Compare::Equal
}

public fun add(self: I128, other: I128): I128 {
    macro::add!(self, other, EOverflow)
}

public fun sub(self: I128, other: I128): I128 {
    self.add(I128 { value: not_u128(other.value) }.wrapping_add(from_u128(1)))
}

public fun mul(self: I128, other: I128): I128 {
    if (self.value == 0 || other.value == 0) return zero();

    if (self.is_positive() != other.is_positive()) {
        negative_from_u128(self.abs_unchecked_u128() * other.abs_unchecked_u128())
    } else {
        from_u128(self.abs_unchecked_u128() * other.abs_unchecked_u128())
    }
}

public fun div(self: I128, other: I128): I128 {
    assert!(other.value != 0, EDivByZero);

    if (self.is_positive() != other.is_positive()) {
        negative_from_u128(self.abs_unchecked_u128() / other.abs_unchecked_u128())
    } else {
        from_u128(self.abs_unchecked_u128() / other.abs_unchecked_u128())
    }
}

public fun div_up(self: I128, other: I128): I128 {
    assert!(other.value != 0, EDivByZero);

    if (self.is_positive() != other.is_positive()) {
        negative_from_u128(
            uint_macro::div_up!(self.abs_unchecked_u128(), other.abs_unchecked_u128()),
        )
    } else {
        from_u128(
            uint_macro::div_up!(self.abs_unchecked_u128(), other.abs_unchecked_u128()),
        )
    }
}

public fun pow(self: I128, exponent: u128): I128 {
    let result = uint_macro::pow!<u128>(self.abs().value as u128, exponent);

    if (self.is_negative() && exponent % 2 != 0) negative_from_u128(result)
    else from_u128(result)
}

public fun mod(self: I128, other: I128): I128 {
    assert!(other.value != 0, EDivByZero);

    let other_abs = other.abs_unchecked_u128();

    if (self.is_negative()) {
        negative_from_u128(self.abs_unchecked_u128() % other_abs)
    } else {
        from_u128(self.value % other_abs)
    }
}

public fun wrapping_add(self: I128, other: I128): I128 {
    I128 {
        value: if (self.value > (MAX_U128 - other.value)) {
            self.value - (MAX_U128 - other.value) - 1
        } else {
            self.value + other.value
        },
    }
}

public fun wrapping_sub(self: I128, other: I128): I128 {
    self.wrapping_add(I128 { value: not_u128(other.value) }.wrapping_add(from_u128(1)))
}

public fun and(self: I128, other: I128): I128 {
    I128 { value: self.value & other.value }
}

public fun or(self: I128, other: I128): I128 {
    I128 { value: self.value | other.value }
}

public fun xor(self: I128, other: I128): I128 {
    I128 { value: self.value ^ other.value }
}

public fun not(self: I128): I128 {
    I128 { value: not_u128(self.value) }
}

public fun shr(self: I128, rhs: u8): I128 {
    assert!(rhs < 128, EInvalidBitShift);

    if (rhs == 0) return self;

    if (self.is_positive()) {
        I128 { value: self.value >> rhs }
    } else {
        I128 { value: self.value >> rhs | MAX_U128 << (128 - rhs) }
    }
}

public fun shl(self: I128, lhs: u8): I128 {
    assert!(lhs < 128, EInvalidBitShift);

    I128 { value: self.value << lhs }
}

// === Private Functions ===

fun abs_unchecked_u128(self: I128): u128 {
    if (self.is_positive()) {
        self.value
    } else {
        not_u128(self.value - 1)
    }
}

fun compare(self: I128, other: I128): Compare {
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

fun sign(self: I128): u8 {
    (self.value >> 127) as u8
}

fun not_u128(value: u128): u128 {
    value ^ MAX_U128
}

fun check_is_positive_and_return_value(self: I128): u128 {
    assert!(self.is_positive(), EUnderflow);
    self.value
}

fun check_overflow(value: u128) {
    assert!(MAX_POSITIVE >= value, EOverflow);
}

fun check_underflow(value: u128) {
    assert!(MIN_NEGATIVE >= value, EUnderflow);
}

fun check_overflow_and_return(value: u128): u128 {
    check_overflow(value);
    value
}

fun check_underflow_and_return(value: u128): u128 {
    check_underflow(value);
    value
}
