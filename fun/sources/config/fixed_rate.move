module memez_fun::memez_fixed_rate_config; 
// === Imports ===  

use sui::dynamic_field as df;

use memez_acl::acl::AuthWitness;

use memez_fun::memez_config::MemezConfig;

// === Constants ===  

// @dev 50,000,000 = 5%
const LIQUIDITY_PROVISION: u64 = 50_000_000__000_000_000;

const TARGET_SUI_LIQUIDITY: u64 = 10_000__000_000_000;

// === Errors === 

#[error]
const EAlreadyInitialized: vector<u8> = b"Fixed rate config already initialized";

// === Structs ===  

public struct MemezFixedRateConfigKey has copy, store, drop()

public struct MemezFixedRateConfig has store {
    target_sui_liquidity: u64,
    liquidity_provision: u64,
}

// === Initializer === 

public fun initialize(config: &mut MemezConfig) {
    let uid_mut = config.uid_mut();
    assert!(!df::exists_(uid_mut, MemezFixedRateConfigKey()), EAlreadyInitialized);

    let memez_fixed_rate_config = MemezFixedRateConfig {
        target_sui_liquidity: TARGET_SUI_LIQUIDITY,
        liquidity_provision: LIQUIDITY_PROVISION,
    };

    df::add(uid_mut, MemezFixedRateConfigKey(), memez_fixed_rate_config);
}

public fun set_target_sui_liquidity(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    let state = state_mut(self);

    state.target_sui_liquidity = amount;
} 

public fun set_liquidity_provision(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    let state = state_mut(self);

    state.liquidity_provision = amount;
} 

// === Public Package Functions === 

public(package) fun get(self: &MemezConfig): vector<u64> {
   let state = state(self);

   vector[
    state.target_sui_liquidity,
    state.liquidity_provision,
   ]
}

// === Private Functions ===  

fun state(config: &MemezConfig): &MemezFixedRateConfig {
    df::borrow(config.uid(), MemezFixedRateConfigKey())
}

fun state_mut(config: &mut MemezConfig): &mut MemezFixedRateConfig {
    df::borrow_mut(config.uid_mut(), MemezFixedRateConfigKey())
}