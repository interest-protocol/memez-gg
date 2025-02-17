// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

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

#[allow(lint(share_owned, self_transfer), unused_function, unused_mut_parameter)]
module memez_fun::memez_stable;

use ipx_coin_standard::ipx_coin_standard::MetadataCap;
use memez_fun::{
    memez_allowed_versions::AllowedVersions,
    memez_config::MemezConfig,
    memez_errors,
    memez_fees::{Allocation, Fee},
    memez_fixed_rate::{Self, FixedRate},
    memez_fun::{Self, MemezFun, MemezMigrator},
    memez_metadata::MemezMetadata,
    memez_migrator_list::MemezMigratorList,
    memez_token_cap::{Self, MemezTokenCap},
    memez_utils::{destroy_or_return, new_treasury},
    memez_versioned::{Self, Versioned}
};
use memez_vesting::memez_vesting::{Self, MemezVesting};
use sui::{balance::Balance, clock::Clock, coin::{Coin, TreasuryCap}, sui::SUI, token::Token};

// === Constants ===

const STABLE_STATE_VERSION_V1: u64 = 1;

// === Structs ===

public struct Stable()

public struct StableState<phantom Meme, phantom Quote> has key, store {
    id: UID,
    meme_reserve: Balance<Meme>,
    dev_allocation: Balance<Meme>,
    dev_vesting_period: u64,
    liquidity_provision: Balance<Meme>,
    fixed_rate: FixedRate<Meme, Quote>,
    meme_token_cap: Option<MemezTokenCap<Meme>>,
    migration_fee: Fee,
    allocation: Allocation<Meme>,
}

// === Public Mutative Functions ===

public fun new<Meme, Quote, ConfigKey, MigrationWitness>(
    config: &MemezConfig,
    migrator_list: &MemezMigratorList,
    meme_treasury_cap: TreasuryCap<Meme>,
    mut creation_fee: Coin<SUI>,
    target_quote_liquidity: u64,
    total_supply: u64,
    is_token: bool,
    metadata: MemezMetadata,
    dev_payload: vector<u64>,
    stake_holders: vector<address>,
    dev: address,
    allowed_versions: AllowedVersions,
    ctx: &mut TxContext,
): MetadataCap {
    allowed_versions.assert_pkg_version();

    let fees = config.fees<ConfigKey>();

    fees.creation().take(&mut creation_fee, ctx);

    creation_fee.destroy_or_return!(ctx);

    let stable_config = config.get_stable<Quote, ConfigKey>(total_supply);

    let meme_token_cap = if (is_token) option::some(memez_token_cap::new(&meme_treasury_cap, ctx))
    else option::none();

    let (ipx_meme_coin_treasury, metadata_cap, mut meme_reserve) = new_treasury!(
        meme_treasury_cap,
        total_supply,
        ctx,
    );

    let allocation = fees.allocation(&mut meme_reserve, stake_holders);

    let dev_allocation = meme_reserve.split(dev_payload[0]);

    let liquidity_provision = meme_reserve.split(stable_config[1]);

    let fixed_rate = memez_fixed_rate::new<Meme, Quote>(
        target_quote_liquidity.min(stable_config[0]),
        meme_reserve.split(stable_config[2]),
        fees.swap(stake_holders),
    );

    let stable_state = StableState<Meme, Quote> {
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

    let mut memez_fun = memez_fun::new<Stable, Meme, Quote, ConfigKey, MigrationWitness>(
        migrator_list,
        memez_versioned::create(STABLE_STATE_VERSION_V1, stable_state, ctx),
        is_token,
        inner_state,
        metadata,
        ipx_meme_coin_treasury,
        0,
        target_quote_liquidity.min(stable_config[0]),
        meme_balance_value,
        total_supply,
        dev,
        ctx,
    );

    let memez_fun_address = memez_fun.address();

    let state = memez_fun.state_mut<Meme, Quote>();

    state.fixed_rate.set_memez_fun(memez_fun_address);

    memez_fun.share();

    metadata_cap
}

public fun pump<Meme, Quote>(
    self: &mut MemezFun<Stable, Meme, Quote>,
    quote_coin: Coin<Quote>,
    allowed_versions: AllowedVersions,
    ctx: &mut TxContext,
): (Coin<Quote>, Coin<Meme>) {
    self.fr_pump!(|self| self.state_mut<Meme, Quote>(), quote_coin, allowed_versions, ctx)
}

public fun pump_token<Meme, Quote>(
    self: &mut MemezFun<Stable, Meme, Quote>,
    quote_coin: Coin<Quote>,
    allowed_versions: AllowedVersions,
    ctx: &mut TxContext,
): (Coin<Quote>, Token<Meme>) {
    self.fr_pump_token!(|self| self.state_mut<Meme, Quote>(), quote_coin, allowed_versions, ctx)
}

public fun dump<Meme, Quote>(
    self: &mut MemezFun<Stable, Meme, Quote>,
    meme_coin: Coin<Meme>,
    allowed_versions: AllowedVersions,
    ctx: &mut TxContext,
): Coin<Quote> {
    self.fr_dump!(|self| self.state_mut<Meme, Quote>(), meme_coin, allowed_versions, ctx)
}

public fun dump_token<Meme, Quote>(
    self: &mut MemezFun<Stable, Meme, Quote>,
    meme_token: Token<Meme>,
    allowed_versions: AllowedVersions,
    ctx: &mut TxContext,
): Coin<Quote> {
    self.fr_dump_token!(|self| self.state_mut<Meme, Quote>(), meme_token, allowed_versions, ctx)
}

public fun migrate<Meme, Quote>(
    self: &mut MemezFun<Stable, Meme, Quote>,
    allowed_versions: AllowedVersions,
    ctx: &mut TxContext,
): MemezMigrator<Meme, Quote> {
    self.fr_migrate!(|self| self.state_mut<Meme, Quote>(), allowed_versions, ctx)
}

public fun dev_allocation_claim<Meme, Quote>(
    self: &mut MemezFun<Stable, Meme, Quote>,
    clock: &Clock,
    allowed_versions: AllowedVersions,
    ctx: &mut TxContext,
): MemezVesting<Meme> {
    allowed_versions.assert_pkg_version();

    self.assert_migrated();
    self.assert_is_dev(ctx);

    let state = self.state_mut<Meme, Quote>();

    memez_vesting::new(
        clock,
        state.dev_allocation.withdraw_all().into_coin(ctx),
        clock.timestamp_ms(),
        state.dev_vesting_period,
        ctx,
    )
}

public fun distribute_stake_holders_allocation<Meme, Quote>(
    self: &mut MemezFun<Stable, Meme, Quote>,
    clock: &Clock,
    allowed_versions: AllowedVersions,
    ctx: &mut TxContext,
) {
    self.distribute_stake_holders_allocation!(
        |self| self.state_mut<Meme, Quote>(),
        clock,
        allowed_versions,
        ctx,
    )
}

public fun to_coin<Meme, Quote>(
    self: &mut MemezFun<Stable, Meme, Quote>,
    meme_token: Token<Meme>,
    ctx: &mut TxContext,
): Coin<Meme> {
    self.to_coin!(|self| self.state_mut<Meme, Quote>(), meme_token, ctx)
}

// === View Functions for FE ===

fun pump_amount<Meme, Quote>(
    self: &mut MemezFun<Stable, Meme, Quote>,
    amount_in: u64,
): vector<u64> {
    self.fr_pump_amount!(|self| (self.state_mut<Meme, Quote>(), 0), amount_in)
}

fun dump_amount<Meme, Quote>(
    self: &mut MemezFun<Stable, Meme, Quote>,
    amount_in: u64,
): vector<u64> {
    self.fr_dump_amount!(|self| (self.state_mut<Meme, Quote>(), 0), amount_in)
}

// === Private Functions ===

fun token_cap<Meme, Quote>(state: &StableState<Meme, Quote>): &MemezTokenCap<Meme> {
    state.meme_token_cap.borrow()
}

fun state<Meme, Quote>(memez_fun: &mut MemezFun<Stable, Meme, Quote>): &StableState<Meme, Quote> {
    let versioned = memez_fun.versioned_mut();
    maybe_upgrade_state_to_latest(versioned);
    versioned.load_value()
}

fun state_mut<Meme, Quote>(
    memez_fun: &mut MemezFun<Stable, Meme, Quote>,
): &mut StableState<Meme, Quote> {
    let versioned = memez_fun.versioned_mut();
    maybe_upgrade_state_to_latest(versioned);
    versioned.load_value_mut()
}

fun maybe_upgrade_state_to_latest(versioned: &mut Versioned) {
    assert!(
        versioned.version() == STABLE_STATE_VERSION_V1,
        memez_errors::outdated_stable_state_version!(),
    );
}

// === Aliases ===

use fun state as MemezFun.state;
use fun state_mut as MemezFun.state_mut;
use fun destroy_or_return as Coin.destroy_or_return;

// === Public Test Only Functions ===

#[test_only]
public fun dev_allocation<Meme, Quote>(self: &mut MemezFun<Stable, Meme, Quote>): u64 {
    let state = self.state<Meme, Quote>();
    state.dev_allocation.value()
}

#[test_only]
public fun liquidity_provision<Meme, Quote>(self: &mut MemezFun<Stable, Meme, Quote>): u64 {
    let state = self.state<Meme, Quote>();
    state.liquidity_provision.value()
}

#[test_only]
public fun fixed_rate<Meme, Quote>(
    self: &mut MemezFun<Stable, Meme, Quote>,
): &FixedRate<Meme, Quote> {
    &self.state<Meme, Quote>().fixed_rate
}

#[test_only]
public fun meme_reserve<Meme, Quote>(self: &mut MemezFun<Stable, Meme, Quote>): &Balance<Meme> {
    &self.state<Meme, Quote>().meme_reserve
}

#[test_only]
public fun dev_vesting_period<Meme, Quote>(self: &mut MemezFun<Stable, Meme, Quote>): u64 {
    self.state<Meme, Quote>().dev_vesting_period
}
