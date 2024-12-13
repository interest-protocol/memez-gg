#[test_only]
module memez_fun::memez_test_helpers;

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
