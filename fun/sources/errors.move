module memez_fun::memez_errors;

// === Constants ===

const EAlreadyInitialized: u64 = 0;

const EBurnTaxExceedsMax: u64 = 1;

const EInvalidTargetSuiLiquidity: u64 = 2;

const EInsufficientValue: u64 = 3;

const EPreMintNotAllowed: u64 = 4;

const EZeroCoin: u64 = 5;

const ESlippage: u64 = 6;

const EOutdatedAuctionStateVersion: u64 = 7;

const ENotBonding: u64 = 8;

const ENotMigrating: u64 = 9;

const ENotMigrated: u64 = 10;

const EInvalidWitness: u64 = 11;

const EInvalidDev: u64 = 12;

const ETokenNotSupported: u64 = 13;

const ETokenSupported: u64 = 14;

const EOutdatedPumpStateVersion: u64 = 15;

const EOutdatedStableStateVersion: u64 = 16;

const EOutdatedPackageVersion: u64 = 17;

const EInvalidPercentages: u64 = 18;

const EInvalidConfig: u64 = 19;

const EModelKeyNotSupported: u64 = 20;

const EInvalidCreationFeeConfig: u64 = 21;

const EZeroTotalSupply: u64 = 22;

const EInvalidUpgrade: u64 = 23;

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

public(package) fun insufficient_value(): u64 {
    EInsufficientValue
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

public(package) fun invalid_config(): u64 {
    EInvalidConfig
}

public(package) fun model_key_not_supported(): u64 {
    EModelKeyNotSupported
}

public(package) fun invalid_creation_fee_config(): u64 {
    EInvalidCreationFeeConfig
}

public(package) fun zero_total_supply(): u64 {
    EZeroTotalSupply
}

public(package) fun invalid_upgrade(): u64 {
    EInvalidUpgrade
}
