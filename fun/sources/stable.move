/*                                     
        GGGGGGGGGGGGG        GGGGGGGGGGGGG     
     GGG::::::::::::G     GGG::::::::::::G     
   GG:::::::::::::::G   GG:::::::::::::::G     
  G:::::GGGGGGGG::::G  G:::::GGGGGGGG::::G     
 G:::::G       GGGGGG G:::::G       GGGGGG     
G:::::G              G:::::G                   
G:::::G              G:::::G                   
G:::::G    GGGGGGGGGGG:::::G    GGGGGGGGGG     
G:::::G    G::::::::GG:::::G    G::::::::G     
G:::::G    GGGGG::::GG:::::G    GGGGG::::G     
G:::::G        G::::GG:::::G        G::::G     
 G:::::G       G::::G G:::::G       G::::G     
  G:::::GGGGGGGG::::G  G:::::GGGGGGGG::::G     
   GG:::::::::::::::G   GG:::::::::::::::G     
     GGG::::::GGG:::G     GGG::::::GGG:::G     
        GGGGGG   GGGG        GGGGGG   GGGG                                           
*/
#[allow(lint(share_owned), unused_function, unused_mut_parameter)]
module memez_fun::memez_stable;

use ipx_coin_standard::ipx_coin_standard::MetadataCap;
use memez_fun::{
    memez_config::MemezConfig,
    memez_errors,
    memez_fees::{Allocation, Fee},
    memez_fixed_rate::{Self, FixedRate},
    memez_fun::{Self, MemezFun, MemezMigrator},
    memez_migrator_list::MemezMigratorList,
    memez_token_cap::{Self, MemezTokenCap},
    memez_utils::{destroy_or_burn, destroy_or_return, new_treasury},
    memez_version::CurrentVersion,
    memez_versioned::{Self, Versioned}
};
use memez_vesting::memez_vesting::{Self, MemezVesting};
use std::string::String;
use sui::{balance::Balance, clock::Clock, coin::{Coin, TreasuryCap}, sui::SUI, token::Token};

// === Constants ===

const STABLE_STATE_VERSION_V1: u64 = 1;

// === Structs ===

public struct Stable()

public struct StableState<phantom Meme> has key, store {
    id: UID,
    meme_reserve: Balance<Meme>,
    dev_allocation: Balance<Meme>,
    dev_vesting_period: u64,
    liquidity_provision: Balance<Meme>,
    fixed_rate: FixedRate<Meme>,
    meme_token_cap: Option<MemezTokenCap<Meme>>,
    migration_fee: Fee,
    allocation: Allocation<Meme>,
}

// === Public Mutative Functions ===

public fun new<Meme, ConfigKey, MigrationWitness>(
    config: &MemezConfig,
    migrator_list: &MemezMigratorList,
    meme_treasury_cap: TreasuryCap<Meme>,
    mut creation_fee: Coin<SUI>,
    target_sui_liquidity: u64,
    total_supply: u64,
    is_token: bool,
    metadata_names: vector<String>,
    metadata_values: vector<String>,
    dev_payload: vector<u64>,
    stake_holders: vector<address>,
    dev: address,
    version: CurrentVersion,
    ctx: &mut TxContext,
): MetadataCap {
    version.assert_is_valid();

    let fees = config.fees<ConfigKey>();

    fees.creation().take(&mut creation_fee, ctx);

    creation_fee.destroy_or_return(ctx);

    let stable_config = config.get_stable<ConfigKey>(total_supply);

    let meme_token_cap = if (is_token) option::some(memez_token_cap::new(&meme_treasury_cap, ctx))
    else option::none();

    let (ipx_meme_coin_treasury, metadata_cap, mut meme_reserve) = new_treasury(
        meme_treasury_cap,
        total_supply,
        ctx,
    );

    let allocation = fees.allocation(&mut meme_reserve, stake_holders);

    let dev_allocation = meme_reserve.split(dev_payload[0]);

    let liquidity_provision = meme_reserve.split(stable_config[1]);

    let fixed_rate = memez_fixed_rate::new(
        target_sui_liquidity.min(stable_config[0]),
        meme_reserve.split(stable_config[2]),
        fees.swap(stake_holders),
    );

    let stable_state = StableState {
        id: object::new(ctx),
        meme_reserve,
        dev_allocation,
        dev_vesting_period: dev_payload[1],
        liquidity_provision,
        fixed_rate,
        meme_token_cap,
        migration_fee: fees.migration(stake_holders),
        allocation,
    };

    let meme_balance_value = stable_state.fixed_rate.meme_balance().value();

    let inner_state = object::id_address(&stable_state);

    let mut memez_fun = memez_fun::new<Stable, Meme, ConfigKey, MigrationWitness>(
        migrator_list,
        memez_versioned::create(STABLE_STATE_VERSION_V1, stable_state, ctx),
        is_token,
        inner_state,
        metadata_names,
        metadata_values,
        ipx_meme_coin_treasury,
        0,
        stable_config[0],
        meme_balance_value,
        dev,
        ctx,
    );

    let memez_fun_address = memez_fun.addy();

    let state = memez_fun.state_mut();

    state.fixed_rate.set_memez_fun(memez_fun_address);

    memez_fun.share();

    metadata_cap
}

public fun pump<Meme>(
    self: &mut MemezFun<Stable, Meme>,
    sui_coin: Coin<SUI>,
    min_amount_out: u64,
    version: CurrentVersion,
    ctx: &mut TxContext,
): (Coin<SUI>, Coin<Meme>) {
    version.assert_is_valid();
    self.assert_is_bonding();
    self.assert_uses_coin();

    let state = self.state_mut();

    let (start_migrating, excess_sui_coin, meme_coin) = state
        .fixed_rate
        .pump(
            sui_coin,
            min_amount_out,
            ctx,
        );

    if (start_migrating) self.set_progress_to_migrating();

    (excess_sui_coin, meme_coin)
}

public fun pump_token<Meme>(
    self: &mut MemezFun<Stable, Meme>,
    sui_coin: Coin<SUI>,
    min_amount_out: u64,
    version: CurrentVersion,
    ctx: &mut TxContext,
): (Coin<SUI>, Token<Meme>) {
    version.assert_is_valid();
    self.assert_is_bonding();
    self.assert_uses_token();

    let state = self.state_mut();

    let (start_migrating, excess_sui_coin, meme_coin) = state
        .fixed_rate
        .pump(
            sui_coin,
            min_amount_out,
            ctx,
        );

    let meme_token = state.token_cap().from_coin(meme_coin, ctx);

    if (start_migrating) self.set_progress_to_migrating();

    (excess_sui_coin, meme_token)
}

public fun dump<Meme>(
    self: &mut MemezFun<Stable, Meme>,
    meme_coin: Coin<Meme>,
    min_amount_out: u64,
    version: CurrentVersion,
    ctx: &mut TxContext,
): Coin<SUI> {
    version.assert_is_valid();
    self.assert_is_bonding();
    self.assert_uses_coin();

    let state = self.state_mut();

    state
        .fixed_rate
        .dump(
            meme_coin,
            min_amount_out,
            ctx,
        )
}

public fun dump_token<Meme>(
    self: &mut MemezFun<Stable, Meme>,
    meme_token: Token<Meme>,
    min_amount_out: u64,
    version: CurrentVersion,
    ctx: &mut TxContext,
): Coin<SUI> {
    version.assert_is_valid();
    self.assert_is_bonding();
    self.assert_uses_token();

    let state = self.state_mut();

    let meme_coin = state.token_cap().to_coin(meme_token, ctx);

    state
        .fixed_rate
        .dump(
            meme_coin,
            min_amount_out,
            ctx,
        )
}

public fun migrate<Meme>(
    self: &mut MemezFun<Stable, Meme>,
    version: CurrentVersion,
    ctx: &mut TxContext,
): MemezMigrator<Meme> {
    version.assert_is_valid();
    self.assert_is_migrating();

    let state = self.state_mut();

    let sui_balance = state.fixed_rate.sui_balance_mut().withdraw_all();

    let liquidity_provision = state.liquidity_provision.withdraw_all();

    state.meme_reserve.destroy_or_burn(ctx);
    state.fixed_rate.meme_balance_mut().destroy_or_burn(ctx);

    let mut sui_coin = sui_balance.into_coin(ctx);

    state.migration_fee.take(&mut sui_coin, ctx);

    self.migrate(sui_coin.into_balance(), liquidity_provision)
}

public fun dev_allocation_claim<Meme>(
    self: &mut MemezFun<Stable, Meme>,
    clock: &Clock,
    version: CurrentVersion,
    ctx: &mut TxContext,
): MemezVesting<Meme> {
    version.assert_is_valid();

    self.assert_migrated();
    self.assert_is_dev(ctx);

    let state = self.state_mut();

    memez_vesting::new(
        clock,
        state.dev_allocation.withdraw_all().into_coin(ctx),
        clock.timestamp_ms(),
        state.dev_vesting_period,
        ctx,
    )
}

public fun distribute_stake_holders_allocation<Meme>(
    self: &mut MemezFun<Stable, Meme>,
    clock: &Clock,
    version: CurrentVersion,
    ctx: &mut TxContext,
) {
    self.distribute_stake_holders_allocation!(|self| self.state_mut(), clock, version, ctx)
}

public fun to_coin<Meme>(
    self: &mut MemezFun<Stable, Meme>,
    meme_token: Token<Meme>,
    ctx: &mut TxContext,
): Coin<Meme> {
    self.to_coin!(|self| self.state_mut(), meme_token, ctx)
}

// === View Functions for FE ===

fun pump_amount<Meme>(self: &mut MemezFun<Stable, Meme>, amount_in: u64): vector<u64> {
    let state = self.state();

    state.fixed_rate.pump_amount(amount_in)
}

fun dump_amount<Meme>(self: &mut MemezFun<Stable, Meme>, amount_in: u64): vector<u64> {
    let state = self.state();

    state.fixed_rate.dump_amount(amount_in)
}

// === Private Functions ===

fun token_cap<Meme>(state: &StableState<Meme>): &MemezTokenCap<Meme> {
    state.meme_token_cap.borrow()
}

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

fun maybe_upgrade_state_to_latest(versioned: &mut Versioned) {
    assert!(
        versioned.version() == STABLE_STATE_VERSION_V1,
        memez_errors::outdated_stable_state_version(),
    );
}

// === Aliases ===

use fun state as MemezFun.state;
use fun state_mut as MemezFun.state_mut;
use fun destroy_or_burn as Balance.destroy_or_burn;
use fun destroy_or_return as Coin.destroy_or_return;

// === Public Test Only Functions ===

#[test_only]
public fun dev_allocation<Meme>(self: &mut MemezFun<Stable, Meme>): u64 {
    let state = self.state();
    state.dev_allocation.value()
}

#[test_only]
public fun liquidity_provision<Meme>(self: &mut MemezFun<Stable, Meme>): u64 {
    let state = self.state();
    state.liquidity_provision.value()
}

#[test_only]
public fun fixed_rate<Meme>(self: &mut MemezFun<Stable, Meme>): &FixedRate<Meme> {
    &self.state().fixed_rate
}

#[test_only]
public fun meme_reserve<Meme>(self: &mut MemezFun<Stable, Meme>): &Balance<Meme> {
    &self.state().meme_reserve
}

#[test_only]
public fun dev_vesting_period<Meme>(self: &mut MemezFun<Stable, Meme>): u64 {
    self.state().dev_vesting_period
}
