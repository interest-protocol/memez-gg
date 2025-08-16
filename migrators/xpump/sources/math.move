module xpump_migrator::math;

public(package) fun sqrt_down(x: u256): u256 {
    sqrt_down_!(x)
}

public(package) fun sqrt_up(x: u256): u256 {
    let r = sqrt_down(x);
    r + if (r * r < x) 1 else 0
}

public(package) macro fun sqrt_down_<$T>($x: _): $T {
    let x = $x as u256;

    if (x == 0) return 0 as $T;

    let mut result = 1 << ((log2_down!(x) >> 1) as u8);

    result = (result + x / result) >> 1;
    result = (result + x / result) >> 1;
    result = (result + x / result) >> 1;
    result = (result + x / result) >> 1;
    result = (result + x / result) >> 1;
    result = (result + x / result) >> 1;
    result = (result + x / result) >> 1;

    min!(result, x / result) as $T
}

public(package) macro fun min($x: _, $y: _): _ {
    if ($x < $y) $x else $y
}

public(package) macro fun log2_down<$T>($x: _): $T {
    let mut x = $x as u256;
    let mut result = 0;
    if (x >> 128 > 0) {
        x = x >> 128;
        result = result + 128;
    };

    if (x >> 64 > 0) {
        x = x >> 64;
        result = result + 64;
    };

    if (x >> 32 > 0) {
        x = x >> 32;
        result = result + 32;
    };

    if (x >> 16 > 0) {
        x = x >> 16;
        result = result + 16;
    };

    if (x >> 8 > 0) {
        x = x >> 8;
        result = result + 8;
    };

    if (x >> 4 > 0) {
        x = x >> 4;
        result = result + 4;
    };

    if (x >> 2 > 0) {
        x = x >> 2;
        result = result + 2;
    };

    if (x >> 1 > 0) result = result + 1;

    result
}