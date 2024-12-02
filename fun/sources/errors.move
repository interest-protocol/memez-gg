module memez_fun::memez_errors;

// === Constants ===

const EAlreadyInitialized: u64 = 0;

const EBurnTaxExceedsMax: u64 = 1;

const EInvalidTargetSuiLiquidity: u64 = 2;

const ENotEnoughSuiForCreationFee: u64 = 3;

const ENotEnoughSuiForMigrationFee: u64 = 4;

const EPreMintNotAllowed: u64 = 5;

const EZeroCoin: u64 = 6;

const ESlippage: u64 = 7;

const EOutdatedAuctionStateVersion: u64 = 8;

const ENotBonding: u64 = 9;

const ENotMigrating: u64 = 10;

const ENotMigrated: u64 = 11;

const EInvalidWitness: u64 = 12;

const EInvalidDev: u64 = 13;

const ETokenNotSupported: u64 = 14;

const ETokenSupported: u64 = 15;

const EOutdatedPumpStateVersion: u64 = 16;

const EOutdatedStableStateVersion: u64 = 17;

const EOutdatedPackageVersion: u64 = 18;

const EInvalidPercentages: u64 = 19;

const EInvalidModelConfig: u64 = 20;

const EModelKeyNotSupported: u64 = 21;

const EWrongRecipientsLength: u64 = 22;

const EZeroTotalSupply: u64 = 23;

// === Public Package Functions ===

public(package) fun already_initialized(): u64 {
    EAlreadyInitialized
}

public(package) fun burn_tax_exceeds_max(): u64 {
    EBurnTaxExceedsMax
}

public(package) fun invalid_target_sui_liquidity(): u64 {
    EInvalidTargetSuiLiquidity
}

public(package) fun not_enough_sui_for_creation_fee(): u64 {
    ENotEnoughSuiForCreationFee
}

public(package) fun not_enough_sui_for_migration_fee(): u64 {
    ENotEnoughSuiForMigrationFee
}

public(package) fun pre_mint_not_allowed(): u64 {
    EPreMintNotAllowed
}

public(package) fun zero_coin(): u64 {
    EZeroCoin
}

public(package) fun slippage(): u64 {
    ESlippage
}

public(package) fun outdated_auction_state_version(): u64 {
    EOutdatedAuctionStateVersion
}

public(package) fun not_bonding(): u64 {
    ENotBonding
}

public(package) fun not_migrating(): u64 {
    ENotMigrating
}

public(package) fun not_migrated(): u64 {
    ENotMigrated
}

public(package) fun invalid_witness(): u64 {
    EInvalidWitness
}

public(package) fun invalid_dev(): u64 {
    EInvalidDev
}

public(package) fun token_not_supported(): u64 {
    ETokenNotSupported
}

public(package) fun token_supported(): u64 {
    ETokenSupported
}

public(package) fun outdated_pump_state_version(): u64 {
    EOutdatedPumpStateVersion
}

public(package) fun outdated_stable_state_version(): u64 {
    EOutdatedStableStateVersion
}

public(package) fun outdated_package_version(): u64 {
    EOutdatedPackageVersion
}

public(package) fun invalid_percentages(): u64 {
    EInvalidPercentages
}

public(package) fun invalid_model_config(): u64 {
    EInvalidModelConfig
}

public(package) fun model_key_not_supported(): u64 {
    EModelKeyNotSupported
}

public(package) fun wrong_recipients_length(): u64 {
    EWrongRecipientsLength
}

public(package) fun zero_total_supply(): u64 {
    EZeroTotalSupply
}
