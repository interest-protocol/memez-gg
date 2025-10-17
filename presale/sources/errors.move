module memez_presale::memez_errors;

// === Package Functions ===

#[test_only]
const ECoinHasNoValue: u64 = 0;

public(package) macro fun coin_has_no_value(): u64 {
    0
}

#[test_only]
const EInvalidBpsPercentages: u64 = 1;

public(package) macro fun invalid_bps_percentages(): u64 {
    1
}
