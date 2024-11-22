module memez_fun::memez_pump_config;

use memez_acl::acl::AuthWitness;
use memez_fun::{memez_config::MemezConfig, memez_utils};
use sui::dynamic_field as df;

// === Constants ===

// @dev 200,000,000 = 20%
const BURN_TAX: u64 = 200_000_000;

const MAX_BURN_TAX: u64 = 500_000_000;

const POW_18: u64 = 1__000_000_000_000_000_000;

// @dev 50,000,000 = 5%
const LIQUIDITY_PROVISION: u64 = { POW_18 / 20 };

const VIRTUAL_LIQUIDITY: u64 = 1_000__000_000_000;

const TARGET_SUI_LIQUIDITY: u64 = 10_000__000_000_000;

// === Errors ===

#[error]
const EAlreadyInitialized: vector<u8> = b"Pump config already initialized";

#[error]
const EBurnTaxExceedsMax: vector<u8> = b"Burn tax exceeds max";

#[error]
const EInvalidTargetSuiLiquidity: vector<u8> = b"Invalid target SUI liquidity";

// === Structs ===

public struct MemezPumpConfigKey has copy, store, drop ()

public struct MemezPumpConfig has store {
    burn_tax: u64,
    virtual_liquidity: u64,
    target_sui_liquidity: u64,
    liquidity_provision: u64,
}

// === Initializer ===

public fun initialize(config: &mut MemezConfig) {
    let uid_mut = config.uid_mut();
    assert!(!df::exists_(uid_mut, MemezPumpConfigKey()), EAlreadyInitialized);

    let memez_pump_config = MemezPumpConfig {
        burn_tax: BURN_TAX,
        virtual_liquidity: VIRTUAL_LIQUIDITY,
        target_sui_liquidity: TARGET_SUI_LIQUIDITY,
        liquidity_provision: LIQUIDITY_PROVISION,
    };

    df::add(uid_mut, MemezPumpConfigKey(), memez_pump_config);
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

// === Public Package Functions ===

public(package) fun get(self: &MemezConfig, total_supply: u64): vector<u64> {
    let state = state(self);

    let liquidity_provision = memez_utils::calculate_wad_percentage(
        state.liquidity_provision,
        total_supply,
    );

    vector[state.burn_tax, state.virtual_liquidity, state.target_sui_liquidity, liquidity_provision]
}

// === Private Functions ===

fun state(config: &MemezConfig): &MemezPumpConfig {
    df::borrow(config.uid(), MemezPumpConfigKey())
}

fun state_mut(config: &mut MemezConfig): &mut MemezPumpConfig {
    df::borrow_mut(config.uid_mut(), MemezPumpConfigKey())
}

// === Test Only Functions ===

#[test_only]
public fun is_initialized(config: &MemezConfig): bool {
    df::exists_(config.uid(), MemezPumpConfigKey())
}
