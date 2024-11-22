module memez_fun::memez_stable_config;

use memez_acl::acl::AuthWitness;
use memez_fun::memez_config::MemezConfig;
use sui::dynamic_field as df;

// === Constants ===

// @dev 50,000,000 = 5%
const LIQUIDITY_PROVISION: u64 = 50_000_000__000_000_000;

const TARGET_SUI_LIQUIDITY: u64 = 10_000__000_000_000;

const MEME_SALE_AMOUNT: u64 = 400_000_000_000;

// === Errors ===

#[error]
const EAlreadyInitialized: vector<u8> = b"Fixed rate config already initialized";

// === Structs ===

public struct MemezStableConfigKey has copy, store, drop ()

public struct MemezStableConfig has store {
    target_sui_liquidity: u64,
    liquidity_provision: u64,
    meme_sale_amount: u64,
}

// === Initializer ===

public fun initialize(config: &mut MemezConfig) {
    let uid_mut = config.uid_mut();
    assert!(!df::exists_(uid_mut, MemezStableConfigKey()), EAlreadyInitialized);

    let memez_stable_config = MemezStableConfig {
        target_sui_liquidity: TARGET_SUI_LIQUIDITY,
        liquidity_provision: LIQUIDITY_PROVISION,
        meme_sale_amount: MEME_SALE_AMOUNT,
    };

    df::add(uid_mut, MemezStableConfigKey(), memez_stable_config);
}

public fun set_target_sui_liquidity(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    let state = state_mut(self);

    state.target_sui_liquidity = amount;
}

public fun set_liquidity_provision(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    let state = state_mut(self);

    state.liquidity_provision = amount;
}

public fun set_meme_sale_amount(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    let state = state_mut(self);

    state.meme_sale_amount = amount;
}

// === Public Package Functions ===

public(package) fun get(self: &MemezConfig): vector<u64> {
    let state = state(self);

    vector[state.target_sui_liquidity, state.liquidity_provision, state.meme_sale_amount]
}

// === Private Functions ===

fun state(config: &MemezConfig): &MemezStableConfig {
    df::borrow(config.uid(), MemezStableConfigKey())
}

fun state_mut(config: &mut MemezConfig): &mut MemezStableConfig {
    df::borrow_mut(config.uid_mut(), MemezStableConfigKey())
}
