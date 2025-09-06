module memez_vesting::memez_vesting_core;

// === Package Functions ===

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
        ($total_allocation * ($timestamp - $start)) / $duration
    }
}
