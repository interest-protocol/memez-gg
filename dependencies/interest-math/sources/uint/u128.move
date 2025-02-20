module interest_math::u128;

use interest_math::uint_macro as macro;

// === Constants ===

const MAX_U128: u256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

// === Try Functions ===

public fun try_add(x: u128, y: u128): (bool, u128) {
    macro::try_add!(x, y, MAX_U128)
}

public fun try_sub(x: u128, y: u128): (bool, u128) {
    macro::try_sub!(x, y)
}

public fun try_mul(x: u128, y: u128): (bool, u128) {
    let (pred, r) = macro::try_mul!(x, y, MAX_U128);
    (pred, r as u128)
}

public fun try_div_down(x: u128, y: u128): (bool, u128) {
    macro::try_div_down!(x, y)
}

public fun try_div_up(x: u128, y: u128): (bool, u128) {
    macro::try_div_up!(x, y)
}

public fun try_mul_div_down(x: u128, y: u128, z: u128): (bool, u128) {
    macro::try_mul_div_down!(x, y, z, MAX_U128)
}

public fun try_mul_div_up(x: u128, y: u128, z: u128): (bool, u128) {
    macro::try_mul_div_up!(x, y, z, MAX_U128)
}

public fun try_mod(x: u128, y: u128): (bool, u128) {
    macro::try_mod!(x, y)
}

// === Arithmetic Functions ===

public fun add(x: u128, y: u128): u128 {
    macro::add!(x, y)
}

public fun sub(x: u128, y: u128): u128 {
    macro::sub!(x, y)
}

public fun mul(x: u128, y: u128): u128 {
    macro::mul!(x, y)
}

public fun div_down(x: u128, y: u128): u128 {
    macro::div_down!(x, y)
}

public fun div_up(a: u128, b: u128): u128 {
    macro::div_up!(a, b)
}

public fun mul_div_down(x: u128, y: u128, z: u128): u128 {
    macro::mul_div_down!(x, y, z)
}

public fun mul_div_up(x: u128, y: u128, z: u128): u128 {
    macro::mul_div_up!(x, y, z)
}

// === Comparison Functions ===

public fun min(a: u128, b: u128): u128 {
    macro::min!(a, b)
}

public fun max(x: u128, y: u128): u128 {
    macro::max!(x, y)
}

public fun clamp(x: u128, lower: u128, upper: u128): u128 {
    macro::clamp!(x, lower, upper)
}

public fun diff(x: u128, y: u128): u128 {
    macro::diff!(x, y)
}

public fun pow(n: u128, e: u128): u128 {
    macro::pow!(n, e)
}

// === Vector Functions ===

public fun sum(nums: vector<u128>): u128 {
    macro::sum!(nums)
}

public fun average(a: u128, b: u128): u128 {
    macro::average!(a, b)
}

public fun average_vector(nums: vector<u128>): u128 {
    macro::average_vector!(nums)
}

// === Square Root Functions ===

public fun sqrt_down(x: u128): u128 {
    macro::sqrt_down!(x)
}

public fun sqrt_up(x: u128): u128 {
    macro::sqrt_up!(x)
}

// === Logarithmic Functions ===

public fun log2_down(x: u128): u8 {
    macro::log2_down!(x)
}

public fun log2_up(x: u128): u16 {
    macro::log2_up!(x)
}

public fun log10_down(x: u128): u8 {
    macro::log10_down!(x)
}

public fun log10_up(x: u128): u8 {
    macro::log10_up!(x)
}

public fun log256_down(x: u128): u8 {
    macro::log256_down!(x)
}

public fun log256_up(x: u128): u8 {
    macro::log256_up!(x)
}

// === Utility Functions ===

public fun max_value(): u128 {
    (MAX_U128 as u128)
}
