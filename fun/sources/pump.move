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
module memez_fun::memez_pump;

use ipx_coin_standard::ipx_coin_standard::{IPXTreasuryStandard, MetadataCap};
use memez_fun::{
    memez_allowed_versions::AllowedVersions,
    memez_config::MemezConfig,
    memez_constant_product::{Self, MemezConstantProduct},
    memez_fees::{Allocation, Fee},
    memez_fun::{new as new_memez_fun_pool, MemezFun, MemezMigrator},
    memez_metadata::MemezMetadata,
    memez_migrator_list::MemezMigratorList,
    memez_pump_config::PumpConfig,
    memez_token_cap::{Self, MemezTokenCap},
    memez_versioned::{Self, Versioned}
};
use sui::{
    balance::{Self, Balance},
    clock::Clock,
    coin::{Coin, TreasuryCap},
    sui::SUI,
    token::Token
};

// === Constants ===

const PUMP_STATE_VERSION_V1: u64 = 1;

// === Structs ===

public struct Pump()

public struct PumpState<phantom Meme, phantom Quote> has key, store {
    id: UID,
    dev_purchase: Balance<Meme>,
    liquidity_provision: Balance<Meme>,
    allocation: Allocation<Meme>,
    constant_product: MemezConstantProduct<Meme, Quote>,
    meme_token_cap: Option<MemezTokenCap<Meme>>,
    migration_fee: Fee,
}

// === Public Mutative Functions ===

public fun new<Meme, Quote, ConfigKey, MigrationWitness>(
    config: &MemezConfig,
    migrator_list: &MemezMigratorList,
    meme_treasury_cap: TreasuryCap<Meme>,
    mut creation_fee: Coin<SUI>,
    pump_config: PumpConfig,
    total_supply: u64,
    is_token: bool,
    first_purchase: Coin<Quote>,
    metadata: MemezMetadata,
    stake_holders: vector<address>,
    dev: address,
    allowed_versions: AllowedVersions,
    ctx: &mut TxContext,
): (MemezFun<Pump, Meme, Quote>, MetadataCap) {
    allowed_versions.assert_pkg_version();

    config.assert_quote_coin<ConfigKey, Quote>();

    let fees = config.fees<ConfigKey>();

    fees.creation().take(&mut creation_fee, ctx);

    fees.assert_dynamic_stake_holders(stake_holders);

    creation_fee.destroy_or_return!(ctx);

    let meme_token_cap = if (is_token) option::some(memez_token_cap::new(&meme_treasury_cap, ctx))
    else option::none();

    let (
        ipx_meme_coin_treasury,
        metadata_cap,
        mut meme_balance,
    ) = meme_treasury_cap.new_ipx_treasury!(total_supply, ctx);

    let allocation = fees.allocation(&mut meme_balance, stake_holders);

    let liquidity_provision = meme_balance.split(pump_config.liquidity_provision(total_supply));

    let meme_balance_value = meme_balance.value();

    let pump_state = PumpState<Meme, Quote> {
        id: object::new(ctx),
        dev_purchase: balance::zero(),
        liquidity_provision,
        constant_product: memez_constant_product::new(
            pump_config.virtual_liquidity(),
            pump_config.target_quote_liquidity(),
            meme_balance,
            fees.swap(stake_holders),
            pump_config.burn_tax(),
        ),
        meme_token_cap,
        migration_fee: fees.migration(stake_holders),
        allocation,
    };

    let inner_state = object::id_address(&pump_state);

    let mut memez_fun = new_memez_fun_pool<Pump, Meme, Quote, ConfigKey, MigrationWitness>(
        migrator_list,
        memez_versioned::create(PUMP_STATE_VERSION_V1, pump_state, ctx),
        is_token,
        inner_state,
        metadata,
        ipx_meme_coin_treasury,
        pump_config.virtual_liquidity(),
        pump_config.target_quote_liquidity(),
        meme_balance_value,
        total_supply,
        dev,
        ctx,
    );

    let memez_fun_address = memez_fun.address();

    let state = memez_fun.state_mut<Meme, Quote>();

    state.constant_product.set_memez_fun(memez_fun_address);

    if (first_purchase.value() != 0) {
        let meme_coin = memez_fun.cp_pump_unchecked!(
            |self| self.state_mut<Meme, Quote>(),
            first_purchase,
            0,
            ctx,
        );

        let state = memez_fun.state_mut<Meme, Quote>();

        state.dev_purchase.join(meme_coin.into_balance());
    } else first_purchase.destroy_zero();

    (memez_fun, metadata_cap)
}

public fun pump<Meme, Quote>(
    self: &mut MemezFun<Pump, Meme, Quote>,
    quote_coin: Coin<Quote>,
    min_amount_out: u64,
    allowed_versions: AllowedVersions,
    ctx: &mut TxContext,
): Coin<Meme> {
    self.cp_pump!<Pump, Meme, Quote, PumpState<Meme, Quote>>(
        |self| self.state_mut<Meme, Quote>(),
        quote_coin,
        min_amount_out,
        allowed_versions,
        ctx,
    )
}

public fun pump_token<Meme, Quote>(
    self: &mut MemezFun<Pump, Meme, Quote>,
    quote_coin: Coin<Quote>,
    min_amount_out: u64,
    allowed_versions: AllowedVersions,
    ctx: &mut TxContext,
): Token<Meme> {
    self.cp_pump_token!(
        |self| self.state_mut<Meme, Quote>(),
        quote_coin,
        min_amount_out,
        allowed_versions,
        ctx,
    )
}

public fun dump<Meme, Quote>(
    self: &mut MemezFun<Pump, Meme, Quote>,
    treasury_cap: &mut IPXTreasuryStandard,
    meme_coin: Coin<Meme>,
    min_amount_out: u64,
    allowed_versions: AllowedVersions,
    ctx: &mut TxContext,
): Coin<Quote> {
    self.cp_dump!(
        |self| self.state_mut<Meme, Quote>(),
        treasury_cap,
        meme_coin,
        min_amount_out,
        allowed_versions,
        ctx,
    )
}

public fun dump_token<Meme, Quote>(
    self: &mut MemezFun<Pump, Meme, Quote>,
    treasury_cap: &mut IPXTreasuryStandard,
    meme_token: Token<Meme>,
    min_amount_out: u64,
    allowed_versions: AllowedVersions,
    ctx: &mut TxContext,
): Coin<Quote> {
    self.cp_dump_token!(
        |self| self.state_mut<Meme, Quote>(),
        treasury_cap,
        meme_token,
        min_amount_out,
        allowed_versions,
        ctx,
    )
}

public fun migrate<Meme, Quote>(
    self: &mut MemezFun<Pump, Meme, Quote>,
    allowed_versions: AllowedVersions,
    ctx: &mut TxContext,
): MemezMigrator<Meme, Quote> {
    allowed_versions.assert_pkg_version();
    self.assert_is_migrating();

    let state = self.state_mut<Meme, Quote>();

    let quote_balance = state.constant_product.quote_balance_mut().withdraw_all();

    let liquidity_provision = if (state.liquidity_provision.value() == 0) {
        state.constant_product.meme_balance_mut().withdraw_all()
    } else {
        state.constant_product.meme_balance_mut().destroy_or_burn!(ctx);
        state.liquidity_provision.withdraw_all()
    };

    let mut quote_coin = quote_balance.into_coin(ctx);

    state.migration_fee.take(&mut quote_coin, ctx);

    self.migrate(liquidity_provision, quote_coin.into_balance())
}

public fun dev_purchase_claim<Meme, Quote>(
    self: &mut MemezFun<Pump, Meme, Quote>,
    allowed_versions: AllowedVersions,
    ctx: &mut TxContext,
): Coin<Meme> {
    allowed_versions.assert_pkg_version();

    self.assert_migrated();
    self.assert_is_dev(ctx);

    let state = self.state_mut<Meme, Quote>();

    state.dev_purchase.withdraw_all().into_coin(ctx)
}

public fun distribute_stake_holders_allocation<Meme, Quote>(
    self: &mut MemezFun<Pump, Meme, Quote>,
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
    self: &mut MemezFun<Pump, Meme, Quote>,
    meme_token: Token<Meme>,
    ctx: &mut TxContext,
): Coin<Meme> {
    self.to_coin!(|self| self.state_mut<Meme, Quote>(), meme_token, ctx)
}

// === View Functions for FE ===

fun pump_amount<Meme, Quote>(self: &mut MemezFun<Pump, Meme, Quote>, amount_in: u64): vector<u64> {
    self.cp_pump_amount!(|self| (self.state<Meme, Quote>()), amount_in)
}

fun dump_amount<Meme, Quote>(self: &mut MemezFun<Pump, Meme, Quote>, amount_in: u64): vector<u64> {
    self.cp_dump_amount!(|self| (self.state<Meme, Quote>()), amount_in)
}

// === Private Functions ===

fun token_cap<Meme, Quote>(state: &PumpState<Meme, Quote>): &MemezTokenCap<Meme> {
    state.meme_token_cap.borrow()
}

fun state<Meme, Quote>(memez_fun: &mut MemezFun<Pump, Meme, Quote>): &PumpState<Meme, Quote> {
    let versioned = memez_fun.versioned_mut();
    maybe_upgrade_state_to_latest(versioned);
    versioned.load_value()
}

fun state_mut<Meme, Quote>(
    memez_fun: &mut MemezFun<Pump, Meme, Quote>,
): &mut PumpState<Meme, Quote> {
    let versioned = memez_fun.versioned_mut();
    maybe_upgrade_state_to_latest(versioned);
    versioned.load_value_mut()
}

fun maybe_upgrade_state_to_latest(versioned: &mut Versioned) {
    assert!(
        versioned.version() == PUMP_STATE_VERSION_V1,
        memez_fun::memez_errors::outdated_pump_state_version!(),
    );
}

// === Aliases ===

use fun state as MemezFun.state;
use fun state_mut as MemezFun.state_mut;
use fun memez_fun::memez_utils::destroy_or_burn as Balance.destroy_or_burn;
use fun memez_fun::memez_utils::destroy_or_return as Coin.destroy_or_return;
use fun memez_fun::memez_utils::new_treasury as TreasuryCap.new_ipx_treasury;

// === Public Test Only Functions ===

#[test_only]
public fun liquidity_provision<Meme, Quote>(self: &mut MemezFun<Pump, Meme, Quote>): u64 {
    let state = self.state<Meme, Quote>();
    state.liquidity_provision.value()
}

#[test_only]
public fun constant_product_mut<Meme, Quote>(
    self: &mut MemezFun<Pump, Meme, Quote>,
): &mut MemezConstantProduct<Meme, Quote> {
    &mut self.state_mut<Meme, Quote>().constant_product
}

#[test_only]
public fun dev_purchase<Meme, Quote>(self: &mut MemezFun<Pump, Meme, Quote>): u64 {
    self.state_mut<Meme, Quote>().dev_purchase.value()
}
