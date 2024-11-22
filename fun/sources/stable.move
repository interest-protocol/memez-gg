module memez_fun::memez_stable;
// === Imports === 

use std::string::String;

use sui::{
    sui::SUI,
    clock::Clock,
    balance::Balance,
    versioned::{Self, Versioned},
    coin::{Coin, TreasuryCap, CoinMetadata},
};

use ipx_coin_standard::ipx_coin_standard::MetadataCap;

use memez_vesting::memez_vesting::{Self, MemezVesting};

use memez_fun::{
    memez_stable_config,
    memez_migrator::Migrator,
    memez_utils::destroy_or_burn,
    memez_version::CurrentVersion,
    memez_config::{Self, MemezConfig},
    memez_fixed_rate::{Self, FixedRate},
    memez_fun::{Self, MemezFun, MemezMigrator}
};

// === Constants ===

const STABLE_STATE_VERSION_V1: u64 = 1;

// === Errors === 

#[error]
const EInvalidVersion: vector<u8> = b"Invalid version";

// === Structs ===

public struct Stable()

public struct StableState<phantom Meme> has store {
    vesting_period: u64,
    meme_reserve: Balance<Meme>,
    dev_allocation: Balance<Meme>, 
    liquidity_provision: Balance<Meme>, 
    fixed_rate: FixedRate<Meme>,
}

// === Public Mutative Functions === 

#[allow(lint(share_owned))]
public fun new<Meme, MigrationWitness>(
    config: &MemezConfig,
    migrator: &Migrator,
    meme_metadata: &CoinMetadata<Meme>,
    meme_treasury_cap: TreasuryCap<Meme>,
    creation_fee: Coin<SUI>,
    metadata_names: vector<String>,
    metadata_values: vector<String>,
    dev_payload: vector<u64>,
    version: CurrentVersion,
    ctx: &mut TxContext
): MetadataCap {
    version.assert_is_valid();
    config.take_creation_fee(creation_fee);

    let stable_config = memez_stable_config::get(config); 

    let (ipx_meme_coin_treasury, metadata_cap, mut meme_reserve) = memez_config::set_up_meme_treasury(meme_metadata, meme_treasury_cap, ctx);

    let dev_allocation = meme_reserve.split(dev_payload[0]); 

    let liquidity_provision = meme_reserve.split(stable_config[1]); 

    let fixed_rate = memez_fixed_rate::new(
        stable_config[0], 
        meme_reserve.split(stable_config[2])
    );

    let stable_state = StableState {
        vesting_period: dev_payload[1],
        meme_reserve,
        dev_allocation,
        liquidity_provision,
        fixed_rate,
    };

    let mut memez_fun = memez_fun::new<Stable, MigrationWitness, Meme>(
        migrator,
        versioned::create(STABLE_STATE_VERSION_V1, stable_state, ctx),
        metadata_names,
        metadata_values,
        ipx_meme_coin_treasury,
        ctx,
    );

    let memez_fun_address = memez_fun.addy();

    let state = memez_fun.state_mut();

    state.fixed_rate.set_memez_fun(memez_fun_address);

    memez_fun.share();

    metadata_cap
}

public fun pump<Meme>(
    self: &mut MemezFun<Stable,Meme>, 
    sui_coin: Coin<SUI>, 
    min_amount_out: u64,
    version: CurrentVersion, 
    ctx: &mut TxContext
): (Coin<SUI>, Coin<Meme>) {
    version.assert_is_valid();
    self.assert_is_bonding();

    let (start_migrating, excess_sui_coin, meme_coin) = self.state_mut().fixed_rate.pump(
        sui_coin,
        min_amount_out,
        ctx
    );

    if (start_migrating)
        self.set_progress_to_migrating();

    (excess_sui_coin, meme_coin)
}

public fun dump<Meme>(
    self: &mut MemezFun<Stable, Meme>, 
    meme_coin: Coin<Meme>, 
    min_amount_out: u64,
    version: CurrentVersion, 
    ctx: &mut TxContext
): Coin<SUI> {
    version.assert_is_valid();
    self.assert_is_bonding();

    self.state_mut().fixed_rate.dump(
        meme_coin,           
        min_amount_out,
        ctx
    )
}

public fun migrate<Meme>(
    self: &mut MemezFun<Stable, Meme>, 
    config: &MemezConfig,
    version: CurrentVersion, 
    ctx: &mut TxContext
): MemezMigrator<Meme> {
    version.assert_is_valid();
    self.assert_is_migrating();

    let state = self.state_mut();

    let mut sui_balance = state.fixed_rate.sui_balance_mut().withdraw_all();

    let liquidity_provision = state.liquidity_provision.withdraw_all();

    state.meme_reserve.destroy_or_burn(ctx);
    state.fixed_rate.meme_balance_mut().destroy_or_burn(ctx);

    config.take_migration_fee(sui_balance.split(config.migration_fee()).into_coin(ctx));

    self.new_migrator(sui_balance, liquidity_provision)
}

public fun dev_claim<Meme>(
    self: &mut MemezFun<Stable, Meme>, 
    clock: &Clock, 
    version: CurrentVersion, 
    ctx: &mut TxContext
): MemezVesting<Meme> {
    self.assert_migrated();
    self.assert_is_dev(ctx); 

    version.assert_is_valid();

    let state = self.state_mut();

    memez_vesting::new(
        clock,
        state.dev_allocation.withdraw_all().into_coin(ctx),
        clock.timestamp_ms(),
        state.vesting_period,
        ctx
    )
}

// === Public View Functions ===  

public fun pump_amount<Meme>(self: &mut MemezFun<Stable, Meme>, amount_in: u64): (u64, u64) {
    let state = self.state();

    state.fixed_rate.pump_amount(amount_in)
}

public fun dump_amount<Meme>(self: &mut MemezFun<Stable, Meme>, amount_in: u64): u64 {
    let state = self.state();

    state.fixed_rate.dump_amount(amount_in)
}

// === Private Functions === 

fun state<Meme>(memez_fun: &mut MemezFun<Stable, Meme>): &StableState<Meme> {
    let versioned = memez_fun.versioned_mut();
    maybe_upgrade_state_to_latest(versioned);
    versioned.load_value()
}

fun state_mut<Meme>(memez_fun: &mut MemezFun<Stable, Meme>): &mut StableState<Meme> {
    let versioned = memez_fun.versioned_mut();
    maybe_upgrade_state_to_latest(versioned);
    versioned.load_value_mut()
}

#[allow(unused_mut_parameter)]
fun maybe_upgrade_state_to_latest(versioned: &mut Versioned) {
    assert!(versioned.version() == STABLE_STATE_VERSION_V1, EInvalidVersion);
}

// === Aliases ===

use fun state as MemezFun.state; 
use fun state_mut as MemezFun.state_mut; 
use fun destroy_or_burn as Balance.destroy_or_burn; 