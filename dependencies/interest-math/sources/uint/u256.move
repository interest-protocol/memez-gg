module interest_math::u256;

use interest_math::uint_macro as macro;

// === Constants ===

const MAX_U256: u256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

// === Try Functions ===

public fun try_add(x: u256, y: u256): (bool, u256) {
    if (x == MAX_U256 && y != 0) return (false, 0);

    let rem = MAX_U256 - x;
    if (y > rem) return (false, 0);

    (true, x + y)
}

public fun try_sub(x: u256, y: u256): (bool, u256) {
    macro::try_sub!(x, y)
}

public fun try_mul(x: u256, y: u256): (bool, u256) {
    macro::try_mul!(x, y, MAX_U256)
}

public fun try_div_down(x: u256, y: u256): (bool, u256) {
    macro::try_div_down!(x, y)
}

public fun try_div_up(x: u256, y: u256): (bool, u256) {
    macro::try_div_up!(x, y)
}

public fun try_mul_div_down(x: u256, y: u256, z: u256): (bool, u256) {
    macro::try_mul_div_down!(x, y, z, MAX_U256)
}

public fun try_mul_div_up(x: u256, y: u256, z: u256): (bool, u256) {
    macro::try_mul_div_up!(x, y, z, MAX_U256)
}

public fun try_mod(x: u256, y: u256): (bool, u256) {
    macro::try_mod!(x, y)
}

// === Arithmetic Functions ===

public fun add(x: u256, y: u256): u256 {
    macro::add!(x, y)
}

public fun sub(x: u256, y: u256): u256 {
    macro::sub!(x, y)
}

public fun mul(x: u256, y: u256): u256 {
    macro::mul!(x, y)
}

public fun div_down(x: u256, y: u256): u256 {
    macro::div_down!(x, y)
}

public fun div_up(x: u256, y: u256): u256 {
    macro::div_up!(x, y)
}

public fun mul_div_down(x: u256, y: u256, z: u256): u256 {
    macro::mul_div_down!(x, y, z)
}

public fun mul_div_up(x: u256, y: u256, z: u256): u256 {
    macro::mul_div_up!(x, y, z)
}

// === Comparison Functions ===

public fun min(x: u256, y: u256): u256 {
    macro::min!(x, y)
}

public fun max(x: u256, y: u256): u256 {
    macro::max!(x, y)
}

public fun clamp(x: u256, lower: u256, upper: u256): u256 {
    macro::clamp!(x, lower, upper)
}

public fun diff(x: u256, y: u256): u256 {
    macro::diff!(x, y)
}

// === Exponential Functions ===

public fun pow(n: u256, e: u256): u256 {
    macro::pow!(n, e)
}

// === Vector Functions ===

public fun sum(nums: vector<u256>): u256 {
    macro::sum!(nums)
}

public fun average(x: u256, y: u256): u256 {
    macro::average!(x, y)
}

public fun average_vector(nums: vector<u256>): u256 {
    macro::average_vector!(nums)
}

// === Square Root Functions ===

public fun sqrt_down(x: u256): u256 {
    macro::sqrt_down!(x)
}

public fun sqrt_up(a: u256): u256 {
    macro::sqrt_up!(a)
}

// === Logarithmic Functions ===

public fun log2_down(value: u256): u8 {
    macro::log2_down!(value)
}

public fun log2_up(value: u256): u16 {
    macro::log2_up!(value)
}

public fun log10_down(value: u256): u8 {
    macro::log10_down!(value)
}

public fun log10_up(value: u256): u8 {
    macro::log10_up!(value)
}

public fun log256_down(x: u256): u8 {
    macro::log256_down!(x)
}

public fun log256_up(x: u256): u8 {
    macro::log256_up!(x)
}

// === Utility Functions ===

public fun max_value(): u256 {
    MAX_U256
}
