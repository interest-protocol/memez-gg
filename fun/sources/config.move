module memez_fun::memez_config; 
// === Imports ===  

use sui::{
    sui::SUI,
    coin::Coin 
};

use memez_acl::acl::AuthWitness;

// === Constants ===  

// @dev 200,000,000 = 20%
const BURN_TAX: u64 = 200_000_000;  

const MAX_BURN_TAX: u64 = 500_000_000;

// @dev 10,000,000 = 1%
const DEV_ALLOCATION: u64 = 10_000_000__000_000_000;

// @dev 50,000,000 = 5%
const LIQUIDITY_PROVISION: u64 = 50_000_000__000_000_000;

const CREATION_FEE: u64 = 2__000_000_000; 

const MIGRATION_FEE: u64 = 200__000_000_000;

const THIRTY_MINUTES_MS: u64 = 30 * 60 * 1_000; 

const VIRTUAL_LIQUIDITY: u64 = 1_000__000_000_000;

const TARGET_SUI_LIQUIDITY: u64 = 10_000__000_000_000;

// === Errors === 

#[error]
const ENotEnoughSuiForCreationFee: vector<u8> = b"Not enough SUI for creation fee";

#[error]
const EBurnTaxExceedsMax: vector<u8> = b"Burn tax exceeds max";

#[error]
const ENotEnoughSuiForMigrationFee: vector<u8> = b"Not enough SUI for migration fee";

#[error]
const EInvalidTargetSuiLiquidity: vector<u8> = b"Invalid target SUI liquidity";

// === Structs ===  

public struct MemezConfig has key {
    id: UID, 
    auction_duration: u64,
    dev_allocation: u64,
    burn_tax: u64,
    treasury: address,
    virtual_liquidity: u64,
    target_sui_liquidity: u64,
    liquidity_provision: u64,
    creation_fee: u64,
    migration_fee: u64,
}

// === Initializer === 

fun init(ctx: &mut TxContext) {
    let config = MemezConfig {
        id: object::new(ctx),
        auction_duration: THIRTY_MINUTES_MS,
        dev_allocation: DEV_ALLOCATION,
        burn_tax: BURN_TAX,
        treasury: @treasury,
        virtual_liquidity: VIRTUAL_LIQUIDITY,
        target_sui_liquidity: TARGET_SUI_LIQUIDITY,
        liquidity_provision: LIQUIDITY_PROVISION,
        creation_fee: CREATION_FEE,
        migration_fee: MIGRATION_FEE,
    };

    transfer::share_object(config);
}

// === Public Admin Functions === 

public fun set_burn_tax(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    assert!(amount <= MAX_BURN_TAX, EBurnTaxExceedsMax);

    self.burn_tax = amount;
}

public fun set_creation_fee(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    self.creation_fee = amount;
}

public fun set_migration_fee(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    self.migration_fee = amount;
}

public fun set_virtual_liquidity(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    self.virtual_liquidity = amount;
}

public fun set_target_sui_liquidity(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    assert!(amount > self.virtual_liquidity, EInvalidTargetSuiLiquidity);

    self.target_sui_liquidity = amount;
} 

public fun set_liquidity_provision(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    self.liquidity_provision = amount;
} 

public fun set_auction_duration(self: &mut MemezConfig, _: &AuthWitness, duration: u64) {
    self.auction_duration = duration;
} 

public fun set_treasury(self: &mut MemezConfig, _: &AuthWitness, treasury: address) {
    self.treasury = treasury;
} 

public fun set_dev_allocation(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    self.dev_allocation = amount;
} 

// === Public Package Functions ===  

public(package) fun migration_fee(self: &MemezConfig): u64 {
    self.migration_fee
}

public(package) fun take_creation_fee(self: &MemezConfig, creation_fee: Coin<SUI>) {
    assert!(creation_fee.value() >= self.creation_fee, ENotEnoughSuiForCreationFee);

    transfer::public_transfer(creation_fee, self.treasury);
}

public(package) fun take_migration_fee(self: &MemezConfig, migration_fee: Coin<SUI>) {
    assert!(migration_fee.value() >= self.migration_fee, ENotEnoughSuiForMigrationFee);

    transfer::public_transfer(migration_fee, self.treasury);
}
 
public(package) fun get(self: &MemezConfig): (u64, u64, u64, u64, u64, u64) {
    (
        self.auction_duration,
        self.dev_allocation,
        self.burn_tax,
        self.virtual_liquidity,
        self.target_sui_liquidity,
        self.liquidity_provision,
    )
}