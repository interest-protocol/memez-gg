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

#[test_only]
const EZeroPrice: u64 = 2;

public(package) macro fun zero_price(): u64 {
    2
}

#[test_only]
const EInvalidStart: u64 = 3;

public(package) macro fun invalid_start(): u64 {
    3
}

#[test_only]
const EInvalidEnd: u64 = 4;

public(package) macro fun invalid_end(): u64 {
    4
}

#[test_only]
const EInvalidLaunch: u64 = 5;

public(package) macro fun invalid_launch(): u64 {
    5
}

#[test_only]
const EInvalidRelease: u64 = 6;

public(package) macro fun invalid_release(): u64 {
    6
}

#[test_only]
const EZeroMaximumPurchase: u64 = 7;

public(package) macro fun zero_maximum_purchase(): u64 {
    7
}

#[test_only]
const EZeroMinimumSuiToRaise: u64 = 8;

public(package) macro fun zero_minimum_sui_to_raise(): u64 {
    8
}

#[test_only]
const EInvalidMaximumSuiToRaise: u64 = 9;

public(package) macro fun invalid_maximum_sui_to_raise(): u64 {
    9
}

#[test_only]
const EZeroCoinDecimals: u64 = 10;

public(package) macro fun zero_coin_decimals(): u64 {
    10
}

#[test_only]
const EZeroCoinTotalSupply: u64 = 11;

public(package) macro fun zero_coin_total_supply(): u64 {
    11
}

#[test_only]
const EInsufficientSuiFee: u64 = 12;

public(package) macro fun insufficient_sui_fee(): u64 {
    12
}