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
#[allow(lint(share_owned), unused_function, unused_mut_parameter)]
module memez_fun::memez_auction;

use interest_bps::bps::{Self, max_bps};
use interest_math::u64;
use ipx_coin_standard::ipx_coin_standard::{IPXTreasuryStandard, MetadataCap};
use memez_fun::{
    memez_allowed_versions::AllowedVersions,
    memez_config::MemezConfig,
    memez_constant_product::{Self, MemezConstantProduct},
    memez_errors,
    memez_fees::{Fee, Allocation},
    memez_fun::{Self, MemezFun, MemezMigrator},
    memez_migrator_list::MemezMigratorList,
    memez_token_cap::{Self, MemezTokenCap},
    memez_utils::{destroy_or_burn, destroy_or_return, new_treasury},
    memez_versioned::{Self, Versioned}
};
use std::string::String;
use sui::{balance::Balance, clock::Clock, coin::{Coin, TreasuryCap}, sui::SUI, token::Token};

// === Constants ===

const AUCTION_STATE_VERSION_V1: u64 = 1;

// === Structs ===

public struct Auction()

public struct AuctionState<phantom Meme, phantom Quote> has key, store {
    id: UID,
    start_time: u64,
    migration_fee: Fee,
    auction_duration: u64,
    initial_reserve: u64,
    accrued_meme_balance: u64,
    allocation: Allocation<Meme>,
    meme_reserve: Balance<Meme>,
    liquidity_provision: Balance<Meme>,
    constant_product: MemezConstantProduct<Meme, Quote>,
    meme_token_cap: Option<MemezTokenCap<Meme>>,
}

// === Public Mutative Functions ===

public fun new<Meme, Quote, ConfigKey, MigrationWitness>(
    config: &MemezConfig,
    migrator_list: &MemezMigratorList,
    clock: &Clock,
    meme_treasury_cap: TreasuryCap<Meme>,
    mut creation_fee: Coin<SUI>,
    total_supply: u64,
    is_token: bool,
    metadata_names: vector<String>,
    metadata_values: vector<String>,
    stake_holders: vector<address>,
    allowed_versions: AllowedVersions,
    ctx: &mut TxContext,
): MetadataCap {
    allowed_versions.assert_pkg_version();

    let fees = config.fees<ConfigKey>();

    fees.creation().take(&mut creation_fee, ctx);

    creation_fee.destroy_or_return(ctx);

    let auction_config = config.get_auction<Quote, ConfigKey>(total_supply);

    let meme_token_cap = if (is_token) option::some(memez_token_cap::new(&meme_treasury_cap, ctx))
    else option::none();

    let (ipx_meme_coin_treasury, metadata_cap, mut meme_reserve) = new_treasury(
        meme_treasury_cap,
        total_supply,
        ctx,
    );

    let allocation = fees.allocation(
        &mut meme_reserve,
        stake_holders,
    );

    let liquidity_provision = meme_reserve.split(auction_config[4]);

    let meme_balance = meme_reserve.split(auction_config[5]);

    let meme_balance_value = meme_balance.value();

    let auction_state = AuctionState<Meme, Quote> {
        id: object::new(ctx),
        start_time: clock.timestamp_ms(),
        auction_duration: auction_config[0],
        initial_reserve: meme_reserve.value(),
        accrued_meme_balance: 0,
        meme_reserve,
        liquidity_provision,
        allocation,
        constant_product: memez_constant_product::new<Meme, Quote>(
            auction_config[2],
            auction_config[3],
            meme_balance,
            fees.swap(stake_holders),
            auction_config[1],
        ),
        meme_token_cap,
        migration_fee: fees.migration(stake_holders),
    };

    let inner_state = object::id_address(&auction_state);

    let mut memez_fun = memez_fun::new<Auction, Meme, Quote, ConfigKey, MigrationWitness>(
        migrator_list,
        memez_versioned::create(AUCTION_STATE_VERSION_V1, auction_state, ctx),
        is_token,
        inner_state,
        metadata_names,
        metadata_values,
        ipx_meme_coin_treasury,
        auction_config[2],
        auction_config[3],
        meme_balance_value,
        ctx.sender(),
        ctx,
    );

    let memez_fun_address = memez_fun.addy();

    let state = memez_fun.state_mut<Meme, Quote>();

    state.constant_product.set_memez_fun(memez_fun_address);

    memez_fun.share();

    metadata_cap
}

public fun pump<Meme, Quote>(
    self: &mut MemezFun<Auction, Meme, Quote>,
    clock: &Clock,
    quote_coin: Coin<Quote>,
    min_amount_out: u64,
    allowed_versions: AllowedVersions,
    ctx: &mut TxContext,
): Coin<Meme> {
    self.cp_pump!<Auction, Meme, Quote, AuctionState<Meme, Quote>>(|self| {
        let state = self.state_mut();
        state.drip(clock);
        state
    }, quote_coin, min_amount_out, allowed_versions, ctx)
}

public fun pump_token<Meme, Quote>(
    self: &mut MemezFun<Auction, Meme, Quote>,
    clock: &Clock,
    quote_coin: Coin<Quote>,
    min_amount_out: u64,
    allowed_versions: AllowedVersions,
    ctx: &mut TxContext,
): Token<Meme> {
    self.cp_pump_token!(|self| {
        let state = self.state_mut();
        state.drip(clock);
        state
    }, quote_coin, min_amount_out, allowed_versions, ctx)
}

public fun dump<Meme, Quote>(
    self: &mut MemezFun<Auction, Meme, Quote>,
    clock: &Clock,
    treasury_cap: &mut IPXTreasuryStandard,
    meme_coin: Coin<Meme>,
    min_amount_out: u64,
    allowed_versions: AllowedVersions,
    ctx: &mut TxContext,
): Coin<Quote> {
    self.cp_dump!(|self| {
        let state = self.state_mut();
        state.drip(clock);
        state
    }, treasury_cap, meme_coin, min_amount_out, allowed_versions, ctx)
}

public fun dump_token<Meme, Quote>(
    self: &mut MemezFun<Auction, Meme, Quote>,
    clock: &Clock,
    treasury_cap: &mut IPXTreasuryStandard,
    meme_token: Token<Meme>,
    min_amount_out: u64,
    allowed_versions: AllowedVersions,
    ctx: &mut TxContext,
): Coin<Quote> {
    self.cp_dump_token!(|self| {
        let state = self.state_mut();
        state.drip(clock);
        state
    }, treasury_cap, meme_token, min_amount_out, allowed_versions, ctx)
}

public fun migrate<Meme, Quote>(
    self: &mut MemezFun<Auction, Meme, Quote>,
    allowed_versions: AllowedVersions,
    ctx: &mut TxContext,
): MemezMigrator<Meme, Quote> {
    allowed_versions.assert_pkg_version();
    self.assert_is_migrating();

    let state = self.state_mut();

    let quote_balance = state.constant_product.quote_balance_mut().withdraw_all();

    let liquidity_provision = state.liquidity_provision.withdraw_all();

    state.constant_product.meme_balance_mut().destroy_or_burn(ctx);
    state.meme_reserve.destroy_or_burn(ctx);

    let mut quote_coin = quote_balance.into_coin(ctx);

    state.migration_fee.take(&mut quote_coin, ctx);

    self.migrate(quote_coin.into_balance(), liquidity_provision)
}

public fun distribute_stake_holders_allocation<Meme, Quote>(
    self: &mut MemezFun<Auction, Meme, Quote>,
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
    self: &mut MemezFun<Auction, Meme, Quote>,
    meme_token: Token<Meme>,
    ctx: &mut TxContext,
): Coin<Meme> {
    self.to_coin!(|self| self.state_mut<Meme, Quote>(), meme_token, ctx)
}

// === View Functions for FE ===

fun pump_amount<Meme, Quote>(
    self: &mut MemezFun<Auction, Meme, Quote>,
    amount_in: u64,
    clock: &Clock,
): vector<u64> {
    self.cp_pump_amount!(|self| {
        let state = self.state<Meme, Quote>();
        let amount = state.expected_drip_amount(clock);
        (state, amount)
    }, amount_in)
}

fun dump_amount<Meme, Quote>(
    self: &mut MemezFun<Auction, Meme, Quote>,
    amount_in: u64,
    clock: &Clock,
): vector<u64> {
    self.cp_dump_amount!(|self| {
        let state = self.state<Meme, Quote>();
        let amount = state.expected_drip_amount(clock);
        (state, amount)
    }, amount_in)
}

fun meme_balance<Meme, Quote>(self: &mut MemezFun<Auction, Meme, Quote>, clock: &Clock): u64 {
    let state = self.state<Meme, Quote>();

    let amount = state.expected_drip_amount(clock);

    state.constant_product.meme_balance().value() + amount
}

// === Private Functions ===

fun expected_drip_amount<Meme, Quote>(self: &AuctionState<Meme, Quote>, clock: &Clock): u64 {
    let current_time = clock.timestamp_ms();

    let progress = current_time - self.start_time;

    let max_bps = max_bps();

    let percentage = bps::new(u64::mul_div_up(progress, max_bps, self.auction_duration).min(
        max_bps,
    ));

    let expected_meme_balance = percentage.calc(self.initial_reserve);

    if (expected_meme_balance <= self.accrued_meme_balance) return 0;

    let meme_delta = expected_meme_balance - self.accrued_meme_balance;

    if (meme_delta == 0) return 0;

    let current_meme_reserve = self.meme_reserve.value();

    meme_delta.min(current_meme_reserve)
}

fun drip<Meme, Quote>(state: &mut AuctionState<Meme, Quote>, clock: &Clock) {
    let amount = state.expected_drip_amount(clock);

    state.accrued_meme_balance = state.accrued_meme_balance + amount;
    state.constant_product.meme_balance_mut().join(state.meme_reserve.split(amount));
}

fun token_cap<Meme, Quote>(state: &AuctionState<Meme, Quote>): &MemezTokenCap<Meme> {
    state.meme_token_cap.borrow()
}

fun state<Meme, Quote>(memez_fun: &mut MemezFun<Auction, Meme, Quote>): &AuctionState<Meme, Quote> {
    let versioned = memez_fun.versioned_mut();
    maybe_upgrade_state_to_latest(versioned);
    versioned.load_value()
}

fun state_mut<Meme, Quote>(
    memez_fun: &mut MemezFun<Auction, Meme, Quote>,
): &mut AuctionState<Meme, Quote> {
    let versioned = memez_fun.versioned_mut();
    maybe_upgrade_state_to_latest(versioned);
    versioned.load_value_mut()
}

fun maybe_upgrade_state_to_latest(versioned: &mut Versioned) {
    assert!(
        versioned.version() == AUCTION_STATE_VERSION_V1,
        memez_errors::outdated_auction_state_version!(),
    );
}

// === Aliases ===

use fun state as MemezFun.state;
use fun state_mut as MemezFun.state_mut;
use fun destroy_or_burn as Balance.destroy_or_burn;
use fun destroy_or_return as Coin.destroy_or_return;

// === Test Only Functions ===

#[test_only]
public fun start_time<Meme, Quote>(self: &mut MemezFun<Auction, Meme, Quote>): u64 {
    self.state<Meme, Quote>().start_time
}

#[test_only]
public fun auction_duration<Meme, Quote>(self: &mut MemezFun<Auction, Meme, Quote>): u64 {
    self.state<Meme, Quote>().auction_duration
}

#[test_only]
public fun initial_reserve<Meme, Quote>(self: &mut MemezFun<Auction, Meme, Quote>): u64 {
    self.state<Meme, Quote>().initial_reserve
}

#[test_only]
public fun meme_reserve<Meme, Quote>(self: &mut MemezFun<Auction, Meme, Quote>): u64 {
    self.state<Meme, Quote>().meme_reserve.value()
}

#[test_only]
public fun constant_product<Meme, Quote>(
    self: &mut MemezFun<Auction, Meme, Quote>,
): &MemezConstantProduct<Meme, Quote> {
    &self.state<Meme, Quote>().constant_product
}

#[test_only]
public fun liquidity_provision<Meme, Quote>(self: &mut MemezFun<Auction, Meme, Quote>): u64 {
    self.state<Meme, Quote>().liquidity_provision.value()
}

#[test_only]
public fun market_cap<Meme, Quote>(
    self: &mut MemezFun<Auction, Meme, Quote>,
    clock: &Clock,
    decimals: u8,
    total_supply: u64,
): u64 {
    let amounts = dump_amount<Meme, Quote>(self, 10u64.pow(decimals), clock);

    u64::mul_div_up(amounts[1], total_supply, 10u64.pow(decimals))
}

#[test_only]
public fun current_meme_balance<Meme, Quote>(
    self: &mut MemezFun<Auction, Meme, Quote>,
    clock: &Clock,
): u64 {
    meme_balance<Meme, Quote>(self, clock)
}

#[test_only]
public fun allocation<Meme, Quote>(self: &mut MemezFun<Auction, Meme, Quote>): &Allocation<Meme> {
    &self.state<Meme, Quote>().allocation
}
