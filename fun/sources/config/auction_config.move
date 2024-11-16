module memez_fun::memez_auction_config; 
// === Imports ===  

use sui::dynamic_field as df;

use memez_acl::acl::AuthWitness;

use memez_fun::memez_config::MemezConfig;

// === Constants ===  

// @dev 200,000,000 = 20%
const BURN_TAX: u64 = 200_000_000;  

const MAX_BURN_TAX: u64 = 500_000_000;

// @dev 10,000,000 = 1%
const DEV_ALLOCATION: u64 = 10_000_000__000_000_000;

// @dev 50,000,000 = 5%
const LIQUIDITY_PROVISION: u64 = 50_000_000__000_000_000;

const THIRTY_MINUTES_MS: u64 = 30 * 60 * 1_000; 

const VIRTUAL_LIQUIDITY: u64 = 1_000__000_000_000;

const TARGET_SUI_LIQUIDITY: u64 = 10_000__000_000_000;

const SEED_LIQUIDITY: u64 = 1__000_000_000;

// === Errors === 

#[error]
const EAlreadyInitialized: vector<u8> = b"Auction config already initialized";

#[error]
const EBurnTaxExceedsMax: vector<u8> = b"Burn tax exceeds max";

#[error]
const EInvalidTargetSuiLiquidity: vector<u8> = b"Invalid target SUI liquidity";

// === Structs ===  

public struct MemezAuctionConfigKey has copy, store, drop()

public struct MemezAuctionConfig has store {
    auction_duration: u64,
    dev_allocation: u64,
    burn_tax: u64,
    virtual_liquidity: u64,
    target_sui_liquidity: u64,
    liquidity_provision: u64,
    seed_liquidity: u64,
}

// === Initializer === 

public fun initialize(config: &mut MemezConfig) {
    let uid_mut = config.uid_mut();
    assert!(!df::exists_(uid_mut, MemezAuctionConfigKey()), EAlreadyInitialized);

    let memez_auction_config = MemezAuctionConfig {
        auction_duration: THIRTY_MINUTES_MS,
        dev_allocation: DEV_ALLOCATION,
        burn_tax: BURN_TAX,
        virtual_liquidity: VIRTUAL_LIQUIDITY,
        target_sui_liquidity: TARGET_SUI_LIQUIDITY,
        liquidity_provision: LIQUIDITY_PROVISION,
        seed_liquidity: SEED_LIQUIDITY,
    };

    df::add(uid_mut, MemezAuctionConfigKey(), memez_auction_config);
}

// === Public Admin Functions === 

public fun set_burn_tax(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    assert!(amount <= MAX_BURN_TAX, EBurnTaxExceedsMax);

    let state = state_mut(self);

    state.burn_tax = amount;
}

public fun set_virtual_liquidity(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    let state = state_mut(self);

    state.virtual_liquidity = amount;
}

public fun set_target_sui_liquidity(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    let state = state_mut(self);

    assert!(amount > state.virtual_liquidity, EInvalidTargetSuiLiquidity);

    state.target_sui_liquidity = amount;
} 

public fun set_liquidity_provision(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    let state = state_mut(self);

    state.liquidity_provision = amount;
} 

public fun set_auction_duration(self: &mut MemezConfig, _: &AuthWitness, duration: u64) {
    let state = state_mut(self);

    state.auction_duration = duration;
} 

public fun set_dev_allocation(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    let state = state_mut(self);

    state.dev_allocation = amount;
} 

public fun set_seed_liquidity(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    let state = state_mut(self);

    state.seed_liquidity = amount;
} 

// === Public Package Functions === 

public(package) fun get(self: &MemezConfig): vector<u64> {
   let state = state(self);

   vector[
    state.auction_duration,
    state.dev_allocation,
    state.burn_tax,
    state.virtual_liquidity,
    state.target_sui_liquidity,
    state.liquidity_provision,
    state.seed_liquidity,
   ]
}

// === Private Functions ===  

fun state(config: &MemezConfig): &MemezAuctionConfig {
    df::borrow(config.uid(), MemezAuctionConfigKey())
}

fun state_mut(config: &mut MemezConfig): &mut MemezAuctionConfig {
    df::borrow_mut(config.uid_mut(), MemezAuctionConfigKey())
}