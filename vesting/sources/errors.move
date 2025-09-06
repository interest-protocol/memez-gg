module memez_vesting::memez_vesting_errors;

// === Package Functions ===

#[test_only]
const EInvalidStart: u64 = 1;

#[test_only]
const EZeroDuration: u64 = 2;

#[test_only]
const EZeroAllocation: u64 = 3;

public(package) macro fun invalid_start(): u64 {
    1
}

public(package) macro fun zero_duration(): u64 {
    2
}

public(package) macro fun zero_allocation(): u64 {
    3
}
