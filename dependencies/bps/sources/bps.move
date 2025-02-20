module interest_bps::bps;

// === Constants ===

/// 1 bps = 0.01%
/// 10,000 bps = 100%
const MAX_BPS: u64 = 10_000;

// === Errors ===

const EOverflow: u64 = 0;

const EUnderflow: u64 = 1;

const EDivideByZero: u64 = 2;

// === Structs ===

/// A struct to represent a percentage in basis points (bps).
public struct BPS(u64) has copy, drop, store;

// === Public Mutative Functions ===

public fun new(bps: u64): BPS {
    BPS(assert_overflow(bps))
}

public fun add(bps_x: BPS, bps_y: BPS): BPS {
    BPS(assert_overflow(bps_x.0 + bps_y.0))
}

public fun sub(bps_x: BPS, bps_y: BPS): BPS {
    assert!(bps_x.0 >= bps_y.0, EUnderflow);
    BPS(bps_x.0 - bps_y.0)
}

/// @scalar is a raw value, not a BPS value.
public fun mul(bps_x: BPS, scalar: u64): BPS {
    BPS(assert_overflow(bps_x.0 * scalar))
}

/// @scalar is a raw value, not a BPS value.
public fun div(bps_x: BPS, scalar: u64): BPS {
    assert!(scalar != 0, EDivideByZero);
    BPS(bps_x.0 / scalar)
}

/// @scalar is a raw value, not a BPS value.
public fun div_up(bps_x: BPS, scalar: u64): BPS {
    assert!(scalar != 0, EDivideByZero);
    BPS(if (bps_x.0 == 0) 0 else 1 + (bps_x.0 - 1) / scalar)
}


/// @total is a raw value, not a BPS value.
/// It rounds down to the nearest integer.
public fun calc(bps: BPS, total: u64): u64 {
    let amount = ((bps.0 as u128) * (total as u128)) / (MAX_BPS as u128);
    amount as u64
}

/// @total is a raw value, not a BPS value.
/// It rounds up to the nearest integer.
public fun calc_up(bps: BPS, total: u64): u64 {
    let (x, y, z) = (bps.0 as u128, total as u128, MAX_BPS as u128);

    let amount = ((x * y) / z) + if ((x * y) % z > 0) 1 else 0;

    amount as u64
}

// === Public View Functions ===

public fun max_bps(): u64 {
    MAX_BPS
}

public fun value(bps: BPS): u64 {
    bps.0
}

// === Private Functions ===

fun assert_overflow(value: u64): u64 {
    assert!(value <= MAX_BPS, EOverflow);
    value
}
