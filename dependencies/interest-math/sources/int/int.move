module interest_math::int_macro;

// === Public Package Functions ===

public(package) macro fun value($x: _): _ {
    let x = $x;
    x.value
}

public(package) macro fun is_positive($x: _, $min_negative: _): bool {
    let x = $x;
    let min_negative = $min_negative;
    min_negative > x.value
}

public(package) macro fun is_negative($x: _, $min_negative: _): bool {
    let x = $x;
    let min_negative = $min_negative;
    (x.value & min_negative) != 0
}

public(package) macro fun add($self: _, $other: _, $error: u64): _ {
    let self = $self;
    let other = $other;
    let error = $error;

    let sum = self.wrapping_add(other);

    let sign_a = self.sign();
    let sign_b = other.sign();
    let sign_sum = sum.sign();

    assert!(!(sign_a == sign_b && sign_a != sign_sum), error);

    sum
}
