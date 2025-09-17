module memez_vesting::memez_vesting_core;

// === Package Functions ===

public(package) fun mul_div(a: u64, b: u64, c: u64): u64 {
    (((a as u256) * (b as u256)) / (c as u256)) as u64
}

public(package) macro fun linear_vesting_amount(
    $start: u64,
    $duration: u64,
    $total_allocation: u64,
    $timestamp: u64,
): u64 {
    if ($timestamp < $start) return 0;
    if ($timestamp > $start + $duration) {
        $total_allocation
    } else {
        mul_div($total_allocation, ($timestamp - $start), $duration)
    }
}
