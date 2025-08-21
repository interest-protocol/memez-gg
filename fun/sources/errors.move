// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

#[allow(unused_const)]
module memez_fun::memez_errors;

// === Constants ===

#[test_only]
const EInsufficientValue: u64 = 0;

#[test_only]
const EPreMintNotAllowed: u64 = 1;

#[test_only]
const EZeroCoin: u64 = 2;

#[test_only]
const ESlippage: u64 = 3;

#[test_only]
const EOutdatedAuctionStateVersion: u64 = 4;

#[test_only]
const ENotBonding: u64 = 5;

#[test_only]
const ENotMigrating: u64 = 6;

#[test_only]
const ENotMigrated: u64 = 7;

#[test_only]
const EInvalidWitness: u64 = 8;

#[test_only]
const EInvalidDev: u64 = 9;

#[test_only]
const ETokenNotSupported: u64 = 10;

#[test_only]
const ETokenSupported: u64 = 11;

#[test_only]
const EOutdatedPumpStateVersion: u64 = 12;

#[test_only]
const EOutdatedStableStateVersion: u64 = 13;

#[test_only]
const EOutdatedPackageVersion: u64 = 14;

#[test_only]
const EInvalidPercentages: u64 = 15;

#[test_only]
const EInvalidConfig: u64 = 16;

#[test_only]
const EModelKeyNotSupported: u64 = 17;

#[test_only]
const EInvalidCreationFeeConfig: u64 = 18;

#[test_only]
const EZeroTotalSupply: u64 = 19;

#[test_only]
const EInvalidUpgrade: u64 = 20;

#[test_only]
const ERemoveCurrentVersionNotAllowed: u64 = 21;

#[test_only]
const EInvalidMemeDecimals: u64 = 22;

#[test_only]
const EInvalidDynamicStakeHolders: u64 = 23;

#[test_only]
const EInvalidBurnTax: u64 = 24;

#[test_only]
const EQuoteCoinNotSupported: u64 = 25;

#[test_only]
const EMigratorWitnessNotSupported: u64 = 26;

#[test_only]
const EInvalidPumpSignature: u64 = 27;

#[test_only]
const EInvalidMetadataCap: u64 = 28;

// === Public Package Functions ===

public(package) macro fun insufficient_value(): u64 {
    0
}

public(package) macro fun pre_mint_not_allowed(): u64 {
    1
}

public(package) macro fun zero_coin(): u64 {
    2
}

public(package) macro fun slippage(): u64 {
    3
}

public(package) macro fun outdated_auction_state_version(): u64 {
    4
}

public(package) macro fun not_bonding(): u64 {
    5
}

public(package) macro fun not_migrating(): u64 {
    6
}

public(package) macro fun not_migrated(): u64 {
    7
}

public(package) macro fun invalid_witness(): u64 {
    8
}

public(package) macro fun invalid_dev(): u64 {
    9
}

public(package) macro fun token_not_supported(): u64 {
    10
}

public(package) macro fun token_supported(): u64 {
    11
}

public(package) macro fun outdated_pump_state_version(): u64 {
    12
}

public(package) macro fun outdated_stable_state_version(): u64 {
    13
}

public(package) macro fun outdated_package_version(): u64 {
    14
}

public(package) macro fun invalid_percentages(): u64 {
    15
}

public(package) macro fun invalid_config(): u64 {
    16
}

public(package) macro fun model_key_not_supported(): u64 {
    17
}

public(package) macro fun invalid_creation_fee_config(): u64 {
    18
}

public(package) macro fun zero_total_supply(): u64 {
    19
}

public(package) macro fun invalid_upgrade(): u64 {
    20
}

public(package) macro fun remove_current_version_not_allowed(): u64 {
    21
}

public(package) macro fun invalid_meme_decimals(): u64 {
    22
}

public(package) macro fun invalid_dynamic_stake_holders(): u64 {
    23
}

public(package) macro fun invalid_burn_tax(): u64 {
    24
}

public(package) macro fun quote_coin_not_supported(): u64 {
    25
}

public(package) macro fun migrator_witness_not_supported(): u64 {
    26
}

public(package) macro fun invalid_pump_signature(): u64 {
    27
}

public(package) macro fun invalid_metadata_cap(): u64 {
    28
}