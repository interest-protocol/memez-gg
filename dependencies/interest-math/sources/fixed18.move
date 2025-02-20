module interest_math::fixed18;

use interest_math::uint_macro as macro;

// === Constants ===

const FIXED_18_BASE: u256 = 1_000_000_000_000_000_000;

const MAX_U256: u256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

// === Structs ===

public struct Fixed18 has copy, drop, store { value: u256 }

// === Conversion Functions ===

public fun raw_value(self: Fixed18): u256 {
    self.value
}

public fun from_u256(value: u256): Fixed18 {
    Fixed18 { value: (value * FIXED_18_BASE) }
}

public fun from_u128(value: u128): Fixed18 {
    Fixed18 { value: ((value as u256) * FIXED_18_BASE) }
}

public fun from_u64(value: u64): Fixed18 {
    Fixed18 { value: ((value as u256) * FIXED_18_BASE) }
}

public fun from_raw_u256(value: u256): Fixed18 {
    Fixed18 { value }
}

public fun from_raw_u128(value: u128): Fixed18 {
    Fixed18 { value: (value as u256) }
}

public fun from_raw_u64(value: u64): Fixed18 {
    Fixed18 { value: (value as u256) }
}

public fun to_u256(x: Fixed18, decimals: u8): u256 {
    let value = macro::mul_div_down!<u256>(x.value, macro::pow!<u256>(10, decimals), FIXED_18_BASE);
    value
}

public fun to_u128(x: Fixed18, decimals: u8): u128 {
    let value = macro::mul_div_down!<u256>(x.value, macro::pow!<u256>(10, decimals), FIXED_18_BASE);
    value as u128
}

public fun to_u64(x: Fixed18, decimals: u8): u64 {
    let value = macro::mul_div_down!<u256>(x.value, macro::pow!<u256>(10, decimals), FIXED_18_BASE);
    value as u64
}

public fun to_u256_up(x: Fixed18, decimals: u8): u256 {
    let value = macro::mul_div_up!<u256>(x.value, macro::pow!<u256>(10, decimals), FIXED_18_BASE);
    value
}

public fun to_u128_up(x: Fixed18, decimals: u8): u128 {
    let value = macro::mul_div_up!<u256>(x.value, macro::pow!<u256>(10, decimals), FIXED_18_BASE);
    value as u128
}

public fun to_u64_up(x: Fixed18, decimals: u8): u64 {
    let value = macro::mul_div_up!<u256>(x.value, macro::pow!<u256>(10, decimals), FIXED_18_BASE);
    value as u64
}

public fun u64_to_fixed18(x: u64, decimals: u8): Fixed18 {
    let value = macro::mul_div_up!(x, FIXED_18_BASE, macro::pow!<u256>(10, decimals));
    Fixed18 { value }
}

public fun u128_to_fixed18(x: u128, decimals: u8): Fixed18 {
    let value = macro::mul_div_up!((x as u256), FIXED_18_BASE, macro::pow!<u256>(10, decimals));
    Fixed18 { value }
}

public fun u256_to_fixed18(x: u256, decimals: u8): Fixed18 {
    let value = macro::mul_div_up!(x, FIXED_18_BASE, macro::pow!<u256>(10, decimals));
    Fixed18 { value }
}

public fun u64_to_fixed18_up(x: u64, decimals: u8): Fixed18 {
    let value = macro::mul_div_up!((x as u256), FIXED_18_BASE, macro::pow!<u256>(10, decimals));
    Fixed18 { value }
}

public fun u128_to_fixed18_up(x: u128, decimals: u8): Fixed18 {
    let value = macro::mul_div_up!((x as u256), FIXED_18_BASE, macro::pow!<u256>(10, decimals));
    Fixed18 { value }
}

public fun u256_to_fixed18_up(x: u256, decimals: u8): Fixed18 {
    let value = macro::mul_div_up!(x, FIXED_18_BASE, macro::pow!<u256>(10, decimals));
    Fixed18 { value }
}

// === Try Functions ===

public fun try_add(x: Fixed18, y: Fixed18): (bool, Fixed18) {
    let (pred, value) = macro::try_add!(x.value, y.value, MAX_U256);
    (pred, Fixed18 { value })
}

public fun try_sub(x: Fixed18, y: Fixed18): (bool, Fixed18) {
    let (pred, value) = macro::try_sub!(x.value, y.value);
    (pred, Fixed18 { value })
}

public fun try_mul_down(x: Fixed18, y: Fixed18): (bool, Fixed18) {
    let (pred, value) = macro::try_mul_div_down!(x.value, y.value, FIXED_18_BASE, MAX_U256);
    (pred, Fixed18 { value })
}

public fun try_mul_up(x: Fixed18, y: Fixed18): (bool, Fixed18) {
    let (pred, value) = macro::try_mul_div_up!(x.value, y.value, FIXED_18_BASE, MAX_U256);
    (pred, Fixed18 { value })
}

public fun try_div_down(x: Fixed18, y: Fixed18): (bool, Fixed18) {
    let (pred, value) = macro::try_mul_div_down!(x.value, FIXED_18_BASE, y.value, MAX_U256);
    (pred, Fixed18 { value })
}

public fun try_div_up(x: Fixed18, y: Fixed18): (bool, Fixed18) {
    let (pred, value) = macro::try_mul_div_up!(x.value, FIXED_18_BASE, y.value, MAX_U256);
    (pred, Fixed18 { value })
}

// === Arithmetic Functions ===

public fun add(x: Fixed18, y: Fixed18): Fixed18 {
    Fixed18 { value: x.value + y.value }
}

public fun sub(x: Fixed18, y: Fixed18): Fixed18 {
    Fixed18 { value: x.value - y.value }
}

public fun mul_down(x: Fixed18, y: Fixed18): Fixed18 {
    let value = macro::mul_div_down!(x.value, y.value, FIXED_18_BASE);
    Fixed18 { value }
}

public fun mul_up(x: Fixed18, y: Fixed18): Fixed18 {
    let value = macro::mul_div_up!(x.value, y.value, FIXED_18_BASE);
    Fixed18 { value }
}

public fun div_down(x: Fixed18, y: Fixed18): Fixed18 {
    let value = macro::mul_div_down!(x.value, FIXED_18_BASE, y.value);
    Fixed18 { value }
}

public fun div_up(x: Fixed18, y: Fixed18): Fixed18 {
    let value = macro::mul_div_up!(x.value, FIXED_18_BASE, y.value);
    Fixed18 { value }
}

// === Utility Functions ===

public fun base(): u256 {
    FIXED_18_BASE
}
