#[test_only]
module memez_fun::memez_test_helpers;
use interest_math::u64;

public macro fun do<$T>($v: vector<$T>, $f: |$T, u64|) {
    let mut v = $v;
    v.reverse();
    let mut i = 0;
    while (v.length() != 0) {
        $f(v.pop_back(), i);
        i = i + 1;
    };
    v.destroy_empty();
}

public fun add_fee(amount_in: u64, fee: u64): u64 {
    u64::mul_div_up(amount_in, 10_000, 10_000 - fee)
}
