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
    memez_fees::{Allocation, Fee},
    memez_fixed_rate::{Self, FixedRate},
    memez_fun::{new as new_memez_fun_pool, MemezFun, MemezMigrator},
    memez_metadata::MemezMetadata,
    memez_stable_config::StableConfig,
    memez_versioned::{Self, Versioned}
};
use memez_vesting::memez_vesting::{Self, MemezVesting};
use sui::{balance::Balance, clock::Clock, coin::{Coin, TreasuryCap}, sui::SUI};

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
    migration_fee: Fee,
    allocation: Allocation<Meme>,
}

// === Public Mutative Functions ===

public fun new<Meme, Quote, ConfigKey, MigrationWitness>(
    config: &MemezConfig,
    meme_treasury_cap: TreasuryCap<Meme>,
    mut creation_fee: Coin<SUI>,
    stable_config: StableConfig,
    metadata: MemezMetadata,
    dev_payload: vector<u64>,
    stake_holders: vector<address>,
    dev: address,
    is_protected: bool,
    allowed_versions: AllowedVersions,
    ctx: &mut TxContext,
): (MemezFun<Stable, Meme, Quote>, MetadataCap) {
    allowed_versions.assert_pkg_version();

    config.assert_quote_coin<ConfigKey, Quote>();
    config.assert_migrator_witness<ConfigKey, MigrationWitness>();

    let fees = config.fees<ConfigKey>();

    fees.creation().take(&mut creation_fee, ctx);

    fees.assert_dynamic_stake_holders(stake_holders);

    creation_fee.destroy_or_return!(ctx);

    let (
        ipx_meme_coin_treasury,
        metadata_cap,
        mut meme_reserve,
    ) = meme_treasury_cap.new_ipx_treasury!(stable_config.total_supply(), ctx);

    let allocation = fees.allocation(&mut meme_reserve, stake_holders);

    let dev_allocation = meme_reserve.split(dev_payload[0]);

    let liquidity_provision = meme_reserve.split(stable_config.liquidity_provision());

    let fixed_rate = memez_fixed_rate::new<Meme, Quote>(
        stable_config.target_quote_liquidity(),
        meme_reserve.split(stable_config.meme_sale_amount()),
        fees.meme_swap(stake_holders),
        fees.quote_swap(stake_holders),
        config.meme_referrer_fee<ConfigKey>(),
        config.quote_referrer_fee<ConfigKey>(),
    );

    let stable_state = StableState<Meme, Quote> {
        id: object::new(ctx),
        meme_reserve,
        dev_allocation,
        dev_vesting_period: dev_payload[1],
        liquidity_provision,
        fixed_rate,
        migration_fee: fees.migration(stake_holders),
        allocation,
    };

    let meme_balance_value = stable_state.fixed_rate.meme_balance().value();

    let inner_state = object::id_address(&stable_state);

    let mut memez_fun = new_memez_fun_pool<Stable, Meme, Quote, ConfigKey, MigrationWitness>(
        memez_versioned::create(STABLE_STATE_VERSION_V1, stable_state, ctx),
        if (is_protected) config.public_key<ConfigKey>()
        else vector[],
        inner_state,
        metadata,
        ipx_meme_coin_treasury,
        0,
        stable_config.target_quote_liquidity(),
        meme_balance_value,
        stable_config.total_supply(),
        dev,
        ctx,
    );

    let memez_fun_address = memez_fun.address();

    let state = memez_fun.state_mut<Meme, Quote>();

    state.fixed_rate.set_memez_fun(memez_fun_address);

    (memez_fun, metadata_cap)
}

public fun pump<Meme, Quote>(
    self: &mut MemezFun<Stable, Meme, Quote>,
    quote_coin: Coin<Quote>,
    referrer: Option<address>,
    signature: Option<vector<u8>>,
    allowed_versions: AllowedVersions,
    ctx: &mut TxContext,
): (Coin<Quote>, Coin<Meme>) {
    self.fr_pump!(
        |self| self.state_mut<Meme, Quote>(),
        quote_coin,
        referrer,
        signature,
        allowed_versions,
        ctx,
    )
}

public fun dump<Meme, Quote>(
    self: &mut MemezFun<Stable, Meme, Quote>,
    meme_coin: Coin<Meme>,
    referrer: Option<address>,
    allowed_versions: AllowedVersions,
    ctx: &mut TxContext,
): Coin<Quote> {
    self.fr_dump!(|self| self.state_mut<Meme, Quote>(), meme_coin, referrer, allowed_versions, ctx)
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

// === Public View Functions ===

public fun quote_pump<Meme, Quote>(
    self: &mut MemezFun<Stable, Meme, Quote>,
    amount_in: u64,
): vector<u64> {
    self.fr_pump_amount!(|self| (self.state<Meme, Quote>(), 0), amount_in)
}

public fun quote_dump<Meme, Quote>(
    self: &mut MemezFun<Stable, Meme, Quote>,
    amount_in: u64,
): vector<u64> {
    self.fr_dump_amount!(|self| (self.state<Meme, Quote>(), 0), amount_in)
}

// === Private Functions ===

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
        memez_fun::memez_errors::outdated_stable_state_version!(),
    );
}

// === Aliases ===

use fun state as MemezFun.state;
use fun state_mut as MemezFun.state_mut;
use fun memez_fun::memez_utils::destroy_or_return as Coin.destroy_or_return;
use fun memez_fun::memez_utils::new_treasury as TreasuryCap.new_ipx_treasury;

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
