module interest_math::i256;

use interest_math::{int_macro as macro, uint_macro};

// === Constants ===

const MAX_U256: u256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

const MAX_POSITIVE: u256 = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

const MIN_NEGATIVE: u256 = 0x8000000000000000000000000000000000000000000000000000000000000000;

// === Errors ===

const EOverflow: u64 = 0;

const EUnderflow: u64 = 1;

const EDivByZero: u64 = 2;

const EUndefined: u64 = 3;

// === Structs ===

public enum Compare has copy, drop, store {
    Less,
    Equal,
    Greater,
}

public struct I256 has copy, drop, store {
    value: u256,
}

// === Public Functions ===

public fun value(self: I256): u256 {
    macro::value!(self)
}

public fun zero(): I256 {
    I256 { value: 0 }
}

public fun max(): I256 {
    I256 { value: MAX_POSITIVE }
}

public fun min(): I256 {
    I256 { value: MIN_NEGATIVE }
}

public fun from_u8(value: u8): I256 {
    I256 { value: value as u256 }
}

public fun from_u32(value: u32): I256 {
    I256 { value: value as u256 }
}

public fun from_u64(value: u64): I256 {
    I256 { value: value as u256 }
}

public fun from_u128(value: u128): I256 {
    I256 { value: value as u256 }
}

public fun from_u256(value: u256): I256 {
    I256 { value: check_overflow_and_return(value) }
}

public fun negative_from_u256(value: u256): I256 {
    if (value == 0) return zero();

    I256 {
        value: not_u256(check_underflow_and_return(value)) + 1 | MIN_NEGATIVE,
    }
}

public fun negative_from(value: u64): I256 {
    negative_from_u256(value as u256)
}

public fun negative_from_u128(value: u128): I256 {
    negative_from_u256(value as u256)
}

public fun to_u8(self: I256): u8 {
    (self.value as u8)
}

public fun to_u256(self: I256): u256 {
    self.check_is_positive_and_return_value()
}

public fun truncate_to_u8(self: I256): u8 {
    ((self.value & 0xFF) as u8)
}

public fun truncate_to_u16(self: I256): u16 {
    ((self.value & 0xFFFF) as u16)
}

public fun truncate_to_u32(self: I256): u32 {
    ((self.value & 0xFFFFFFFF) as u32)
}

public fun truncate_to_u64(self: I256): u64 {
    ((self.value & 0xFFFFFFFFFFFFFFFF) as u64)
}

public fun truncate_to_u128(self: I256): u128 {
    ((self.value & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF) as u128)
}

public fun is_negative(self: I256): bool {
    macro::is_negative!(self, MIN_NEGATIVE)
}

public fun is_positive(self: I256): bool {
    macro::is_positive!(self, MIN_NEGATIVE)
}

public fun is_zero(self: I256): bool {
    self.value == 0
}

public fun abs(self: I256): I256 {
    if (self.is_negative()) {
        assert!(self.value > MIN_NEGATIVE, EUnderflow);
        I256 { value: not_u256(self.value - 1) }
    } else {
        self
    }
}

public fun eq(self: I256, other: I256): bool {
    self.compare(other) == Compare::Equal
}

public fun lt(self: I256, other: I256): bool {
    self.compare(other) == Compare::Less
}

public fun gt(self: I256, other: I256): bool {
    self.compare(other) == Compare::Greater
}

public fun lte(self: I256, other: I256): bool {
    let pred = self.compare(other);
    pred == Compare::Less || pred == Compare::Equal
}

public fun gte(self: I256, other: I256): bool {
    let pred = self.compare(other);
    pred == Compare::Greater || pred == Compare::Equal
}

public fun add(self: I256, other: I256): I256 {
    macro::add!(self, other, EOverflow)
}

public fun sub(self: I256, other: I256): I256 {
    self.add(I256 { value: not_u256(other.value) }.wrapping_add(from_u256(1)))
}

public fun mul(self: I256, other: I256): I256 {
    if (self.value == 0 || other.value == 0) return zero();
    if (self.is_positive() != other.is_positive()) {
        negative_from_u256(self.abs_unchecked_u256() * other.abs_unchecked_u256())
    } else {
        from_u256(self.abs_unchecked_u256() * other.abs_unchecked_u256())
    }
}

public fun div(self: I256, other: I256): I256 {
    assert!(other.value != 0, EDivByZero);

    if (self.is_positive() != other.is_positive()) {
        negative_from_u256(self.abs_unchecked_u256() / other.abs_unchecked_u256())
    } else {
        from_u256(self.abs_unchecked_u256() / other.abs_unchecked_u256())
    }
}

public fun div_up(self: I256, other: I256): I256 {
    assert!(other.value != 0, EDivByZero);

    if (self.is_positive() != other.is_positive()) {
        negative_from_u256(
            uint_macro::div_up!(self.abs_unchecked_u256(), other.abs_unchecked_u256()),
        )
    } else {
        from_u256(
            uint_macro::div_up!(self.abs_unchecked_u256(), other.abs_unchecked_u256()),
        )
    }
}

public fun mod(self: I256, other: I256): I256 {
    assert!(other.value != 0, EDivByZero);

    let other_abs = other.abs_unchecked_u256();

    if (self.is_negative()) {
        negative_from_u256(self.abs_unchecked_u256() % other_abs)
    } else {
        from_u256(self.value % other_abs)
    }
}

public fun pow(self: I256, exponent: u256): I256 {
    let result = uint_macro::pow!<u256>(self.abs().value, exponent);

    if (self.is_negative() && exponent % 2 != 0) negative_from_u256(result)
    else from_u256(result)
}

public fun wrapping_add(self: I256, other: I256): I256 {
    I256 {
        value: if (self.value > (MAX_U256 - other.value)) {
            self.value - (MAX_U256 - other.value) - 1
        } else {
            self.value + other.value
        },
    }
}

public fun wrapping_sub(self: I256, other: I256): I256 {
    self.wrapping_add(I256 { value: not_u256(other.value) }.wrapping_add(from_u256(1)))
}

public fun and(self: I256, other: I256): I256 {
    I256 { value: self.value & other.value }
}

public fun or(self: I256, other: I256): I256 {
    I256 { value: self.value | other.value }
}

public fun xor(self: I256, other: I256): I256 {
    I256 { value: self.value ^ other.value }
}

public fun not(self: I256): I256 {
    I256 { value: not_u256(self.value) }
}

public fun shr(self: I256, rhs: u8): I256 {
    if (rhs == 0) return self;

    if (self.is_positive()) {
        I256 { value: self.value >> rhs }
    } else {
        I256 { value: self.value >> rhs | MAX_U256 << ((256 - (rhs as u16) as u8)) }
    }
}

public fun shl(self: I256, lhs: u8): I256 {
    I256 { value: self.value << lhs }
}

// === Fixed Point 18 Decimals Precision ===

// === Logarithmic Functions ===

public fun ln(mut x: I256): I256 {
    assert!(x.is_positive() && !x.is_zero(), EUndefined);

    let k = from_u8(uint_macro::log2_down!(x.to_u256())).sub(from_u256(96));

    x = x.shl(from_u8(159).sub(k).to_u8());
    x = from_u256(value(x) >> 159);

    let mut p = x.add(from_u256(3273285459638523848632254066296));
    p =
        p
            .mul(x)
            .shr(96)
            .add(
                from_u256(24828157081833163892658089445524),
            );
    p =
        p
            .mul(x)
            .shr(96)
            .add(
                from_u256(43456485725739037958740375743393),
            );
    p =
        p
            .mul(x)
            .shr(96)
            .sub(
                from_u256(11111509109440967052023855526967),
            );
    p =
        p
            .mul(x)
            .shr(96)
            .sub(
                from_u256(45023709667254063763336534515857),
            );
    p =
        p
            .mul(x)
            .shr(96)
            .sub(
                from_u256(14706773417378608786704636184526),
            );

    p = p.mul(x).sub(from_u256(795164235651350426258249787498 << 96));

    let mut q = x.add(from_u256(5573035233440673466300451813936));

    q =
        q
            .mul(x)
            .shr(96)
            .add(
                from_u256(71694874799317883764090561454958),
            );
    q =
        q
            .mul(x)
            .shr(96)
            .add(
                from_u256(283447036172924575727196451306956),
            );
    q =
        q
            .mul(x)
            .shr(96)
            .add(
                from_u256(401686690394027663651624208769553),
            );
    q =
        q
            .mul(x)
            .shr(96)
            .add(
                from_u256(204048457590392012362485061816622),
            );
    q =
        q
            .mul(x)
            .shr(96)
            .add(
                from_u256(31853899698501571402653359427138),
            );
    q = q.mul(x).shr(96).add(from_u256(909429971244387300277376558375));

    let mut r = p.div(q);
    r = r.mul(from_u256(1677202110996718588342820967067443963516166));
    r =
        r.add(from_u256(
            16597577552685614221487285958193947469193820559219878177908093499208371,
        ).mul(
            k,
        ));
    r =
        r.add(
            from_u256(
                600920179829731861736702779321621459595472258049074101567377883020018308,
            ),
        );

    r.shr(174)
}

// === Exponential Functions ===

public fun exp(x: I256): I256 {
    if (x.lte(negative_from_u256(42139678854452767551))) return zero();

    assert!(x.lt(from_u256(135305999368893231589)), EOverflow);

    let mut x = x.shl(78).div(from_u256(uint_macro::pow!(5, 18)));

    let k = x
        .shl(96)
        .div(from_u256(54916777467707473351141471128))
        .add(from_u256(uint_macro::pow!(2, 95)))
        .shr(96);

    x = x.sub(k.mul(from_u256(54916777467707473351141471128)));

    let mut y = x.add(from_u256(1346386616545796478920950773328));
    y =
        y
            .mul(x)
            .shr(96)
            .add(
                from_u256(57155421227552351082224309758442),
            );
    let mut p = y.add(x).sub(from_u256(94201549194550492254356042504812));
    p =
        p
            .mul(y)
            .shr(96)
            .add(
                from_u256(28719021644029726153956944680412240),
            );
    p = p.mul(x).add(from_u256(4385272521454847904659076985693276 << 96));

    let mut q = x.sub(from_u256(2855989394907223263936484059900));
    q =
        q
            .mul(x)
            .shr(96)
            .add(
                from_u256(50020603652535783019961831881945),
            );

    q = q.mul(x).shr(96).sub(from_u256(533845033583426703283633433725380));
    q = q.mul(x).shr(96).add(from_u256(3604857256930695427073651918091429));
    q = q.mul(x).shr(96).sub(from_u256(14423608567350463180887372962807573));
    q = q.mul(x).shr(96).add(from_u256(26449188498355588339934803723976023));

    let r = p.div(q);

    from_u256(
        (r.to_u256() * 3822833074963236453042738258902158003155416615667) >>
            from_u8(195).sub(k).to_u8(),
    )
}

// === Private Functions ===

fun abs_unchecked_u256(self: I256): u256 {
    if (self.is_positive()) {
        self.value
    } else {
        not_u256(self.value - 1)
    }
}

fun compare(self: I256, other: I256): Compare {
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

fun sign(self: I256): u8 {
    (self.value >> 255) as u8
}

fun not_u256(value: u256): u256 {
    value ^ MAX_U256
}

fun check_is_positive_and_return_value(self: I256): u256 {
    assert!(self.is_positive(), EUnderflow);
    self.value
}

fun check_overflow(value: u256) {
    assert!(MAX_POSITIVE >= value, EOverflow);
}

fun check_underflow(value: u256) {
    assert!(MIN_NEGATIVE >= value, EUnderflow);
}

fun check_overflow_and_return(value: u256): u256 {
    check_overflow(value);
    value
}

fun check_underflow_and_return(value: u256): u256 {
    check_underflow(value);
    value
}
