module memez_fun::memez_errors;

// === Constants ===

const EAlreadyInitialized: u64 = 0;

const EBurnTaxExceedsMax: u64 = 1;

const EInvalidTargetSuiLiquidity: u64 = 2;

const ENotEnoughSuiForCreationFee: u64 = 3;

const ENotEnoughSuiForMigrationFee: u64 = 4;

const EPreMintNotAllowed: u64 = 5;

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
