module memez_fun::memez_stable_config;

use memez_acl::acl::AuthWitness;
use memez_fun::{memez_config::MemezConfig, memez_errors, memez_utils};
use sui::dynamic_field as df;

// === Constants ===
const POW_9: u64 = 1__000_000_000;

const POW_18: u64 = 1__000_000_000_000_000_000;

// @dev 50,000,000 = 5%
const LIQUIDITY_PROVISION: u64 = { POW_18 / 20 };

const TARGET_SUI_LIQUIDITY: u64 = { 10_000 * POW_9 };

const MEME_SALE_AMOUNT: u64 = { 40 * (POW_18 / 100) };

// === Structs ===

public struct MemezStableConfigKey has copy, store, drop ()

public struct MemezStableConfig has store {
    target_sui_liquidity: u64,
    liquidity_provision: u64,
    meme_sale_amount: u64,
}

// === Initializer ===

entry fun initialize(config: &mut MemezConfig) {
    let uid_mut = config.uid_mut();
    assert!(!df::exists_(uid_mut, MemezStableConfigKey()), memez_errors::already_initialized());

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

public(package) fun get(self: &MemezConfig, total_supply: u64): vector<u64> {
    let state = state(self);

    let liquidity_provision = memez_utils::calculate_wad_percentage(
        state.liquidity_provision,
        total_supply,
    );

    let meme_sale_amount = memez_utils::calculate_wad_percentage(
        state.meme_sale_amount,
        total_supply,
    );

    vector[state.target_sui_liquidity, liquidity_provision, meme_sale_amount]
}

// === Private Functions ===

fun state(config: &MemezConfig): &MemezStableConfig {
    df::borrow(config.uid(), MemezStableConfigKey())
}

fun state_mut(config: &mut MemezConfig): &mut MemezStableConfig {
    df::borrow_mut(config.uid_mut(), MemezStableConfigKey())
}

// === Test Only Functions ===

#[test_only]
public fun is_initialized(config: &MemezConfig): bool {
    df::exists_(config.uid(), MemezStableConfigKey())
}
