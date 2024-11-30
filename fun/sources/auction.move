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
module memez_fun::memez_auction;

use interest_math::u64;
use ipx_coin_standard::ipx_coin_standard::{IPXTreasuryStandard, MetadataCap};
use memez_fun::{
    memez_config::{Self, MemezConfig},
    memez_constant_product::{Self, MemezConstantProduct},
    memez_errors,
    memez_fee_model::FeeModel,
    memez_fun::{Self, MemezFun, MemezMigrator},
    memez_migrator_list::MemezMigratorList,
    memez_token_cap::{Self, MemezTokenCap},
    memez_utils::{destroy_or_burn, destroy_or_return, pow_9},
    memez_version::CurrentVersion
};
use std::string::String;
use sui::{
    balance::Balance,
    clock::Clock,
    coin::{Coin, TreasuryCap},
    sui::SUI,
    token::Token,
    versioned::{Self, Versioned}
};

// === Constants ===

const AUCTION_STATE_VERSION_V1: u64 = 1;

// === Structs ===

public struct Auction()

public struct AuctionState<phantom Meme> has store {
    start_time: u64,
    fee_model: FeeModel,
    auction_duration: u64,
    initial_reserve: u64,
    accrued_meme_balance: u64,
    meme_reserve: Balance<Meme>,
    dev_allocation: Balance<Meme>,
    liquidity_provision: Balance<Meme>,
    constant_product: MemezConstantProduct<Meme>,
    meme_token_cap: Option<MemezTokenCap<Meme>>,
}

// === Public Mutative Functions ===

#[allow(lint(share_owned))]
public fun new<Meme, MigrationWitness, ConfigKey>(
    config: &MemezConfig,
    migrator_list: &MemezMigratorList,
    clock: &Clock,
    meme_treasury_cap: TreasuryCap<Meme>,
    mut creation_fee: Coin<SUI>,
    total_supply: u64,
    is_token: bool,
    metadata_names: vector<String>,
    metadata_values: vector<String>,
    version: CurrentVersion,
    ctx: &mut TxContext,
): MetadataCap {
    version.assert_is_valid();

    let fee_model = config.fee_model<ConfigKey>();

    fee_model.new_fee().send(&mut creation_fee, ctx);

    creation_fee.destroy_or_return(ctx);

    let auction_config = config.get_auction<ConfigKey>(total_supply);

    let meme_token_cap = if (is_token) option::some(memez_token_cap::new(&meme_treasury_cap, ctx))
    else option::none();

    let (
        ipx_meme_coin_treasury,
        metadata_cap,
        mut meme_reserve,
    ) = memez_config::set_up_meme_treasury(meme_treasury_cap, total_supply, ctx);

    let dev_allocation = meme_reserve.split(auction_config[1]);

    let liquidity_provision = meme_reserve.split(auction_config[5]);

    let meme_balance = meme_reserve.split(auction_config[6]);

    let auction_state = AuctionState<Meme> {
        start_time: clock.timestamp_ms(),
        auction_duration: auction_config[0],
        initial_reserve: meme_reserve.value(),
        accrued_meme_balance: 0,
        meme_reserve,
        dev_allocation,
        liquidity_provision,
        constant_product: memez_constant_product::new(
            auction_config[3],
            auction_config[4],
            meme_balance,
            auction_config[2],
        ),
        meme_token_cap,
        fee_model,
    };

    let mut memez_fun = memez_fun::new<Auction, MigrationWitness, Meme>(
        migrator_list,
        versioned::create(AUCTION_STATE_VERSION_V1, auction_state, ctx),
        is_token,
        metadata_names,
        metadata_values,
        ipx_meme_coin_treasury,
        ctx,
    );

    let memez_fun_address = memez_fun.addy();

    let state = memez_fun.state_mut();

    state.constant_product.set_memez_fun(memez_fun_address);

    memez_fun.share();

    metadata_cap
}

public fun pump<Meme>(
    self: &mut MemezFun<Auction, Meme>,
    clock: &Clock,
    mut sui_coin: Coin<SUI>,
    min_amount_out: u64,
    version: CurrentVersion,
    ctx: &mut TxContext,
): Coin<Meme> {
    version.assert_is_valid();
    self.assert_uses_coin();
    self.assert_is_bonding();

    let state = self.state_mut();

    state.provide_liquidity(clock);

    state.fee_model.swap_fee().send(&mut sui_coin, ctx);

    let (start_migrating, meme_coin) = state
        .constant_product
        .pump(
            sui_coin,
            min_amount_out,
            ctx,
        );

    if (start_migrating) self.set_progress_to_migrating();

    meme_coin
}

public fun pump_token<Meme>(
    self: &mut MemezFun<Auction, Meme>,
    clock: &Clock,
    mut sui_coin: Coin<SUI>,
    min_amount_out: u64,
    version: CurrentVersion,
    ctx: &mut TxContext,
): Token<Meme> {
    version.assert_is_valid();
    self.assert_uses_token();
    self.assert_is_bonding();

    let state = self.state_mut();

    state.provide_liquidity(clock);

    state.fee_model.swap_fee().send(&mut sui_coin, ctx);

    let (start_migrating, meme_coin) = state
        .constant_product
        .pump(
            sui_coin,
            min_amount_out,
            ctx,
        );

    let meme_token = state.token_cap().from_coin(meme_coin, ctx);

    if (start_migrating) self.set_progress_to_migrating();

    meme_token
}

public fun dump<Meme>(
    self: &mut MemezFun<Auction, Meme>,
    clock: &Clock,
    treasury_cap: &mut IPXTreasuryStandard,
    mut meme_coin: Coin<Meme>,
    min_amount_out: u64,
    version: CurrentVersion,
    ctx: &mut TxContext,
): Coin<SUI> {
    version.assert_is_valid();
    self.assert_uses_coin();
    self.assert_is_bonding();

    let state = self.state_mut();

    state.provide_liquidity(clock);

    state.fee_model.swap_fee().send(&mut meme_coin, ctx);

    state
        .constant_product
        .dump(
            treasury_cap,
            meme_coin,
            min_amount_out,
            ctx,
        )
}

public fun dump_token<Meme>(
    self: &mut MemezFun<Auction, Meme>,
    clock: &Clock,
    treasury_cap: &mut IPXTreasuryStandard,
    meme_token: Token<Meme>,
    min_amount_out: u64,
    version: CurrentVersion,
    ctx: &mut TxContext,
): Coin<SUI> {
    version.assert_is_valid();
    self.assert_uses_token();
    self.assert_is_bonding();

    let state = self.state_mut();

    state.provide_liquidity(clock);

    let mut meme_coin = state.token_cap().to_coin(meme_token, ctx);

    state.fee_model.swap_fee().send(&mut meme_coin, ctx);

    state
        .constant_product
        .dump(
            treasury_cap,
            meme_coin,
            min_amount_out,
            ctx,
        )
}

public fun migrate<Meme>(
    self: &mut MemezFun<Auction, Meme>,
    version: CurrentVersion,
    ctx: &mut TxContext,
): MemezMigrator<Meme> {
    version.assert_is_valid();
    self.assert_is_migrating();

    let state = self.state_mut();

    let sui_balance = state.constant_product.sui_balance_mut().withdraw_all();

    let liquidity_provision = state.liquidity_provision.withdraw_all();

    state.constant_product.meme_balance_mut().destroy_or_burn(ctx);
    state.meme_reserve.destroy_or_burn(ctx);

    let mut sui_coin = sui_balance.into_coin(ctx);

    state.fee_model.migration_fee().send(&mut sui_coin, ctx);

    self.migrate(sui_coin.into_balance(), liquidity_provision)
}

public fun dev_claim<Meme>(
    self: &mut MemezFun<Auction, Meme>,
    version: CurrentVersion,
    ctx: &mut TxContext,
): Coin<Meme> {
    self.assert_migrated();
    self.assert_is_dev(ctx);

    version.assert_is_valid();

    let state = self.state_mut();

    state.dev_allocation.withdraw_all().into_coin(ctx)
}

public fun to_coin<Meme>(
    self: &mut MemezFun<Auction, Meme>,
    meme_token: Token<Meme>,
    ctx: &mut TxContext,
): Coin<Meme> {
    self.assert_migrated();
    self.state_mut().token_cap().to_coin(meme_token, ctx)
}

// === View Functions for FE ===

#[allow(unused_function)]
fun pump_amount<Meme>(self: &mut MemezFun<Auction, Meme>, amount_in: u64, clock: &Clock): u64 {
    let state = self.state();

    let amount = new_liquidity_amount(state, clock);

    state
        .constant_product
        .pump_amount(
            amount_in,
            amount,
        )
}

#[allow(unused_function)]
fun dump_amount<Meme>(
    self: &mut MemezFun<Auction, Meme>,
    amount_in: u64,
    clock: &Clock,
): (u64, u64, u64) {
    let state = self.state();

    let amount = new_liquidity_amount(state, clock);

    state.constant_product.dump_amount(amount_in, amount)
}

#[allow(unused_function)]
fun meme_balance<Meme>(self: &mut MemezFun<Auction, Meme>, clock: &Clock): u64 {
    let state = self.state();

    let amount = new_liquidity_amount(state, clock);

    state.constant_product.meme_balance().value() + amount
}

// === Private Functions ===

fun new_liquidity_amount<Meme>(self: &AuctionState<Meme>, clock: &Clock): u64 {
    let current_time = clock.timestamp_ms();

    let progress = current_time - self.start_time;

    let pow_9 = pow_9();

    let percentage = u64::mul_div_up(progress, pow_9, self.auction_duration).min(pow_9);

    let expected_meme_balance = u64::mul_div_up(self.initial_reserve, percentage, pow_9);

    if (expected_meme_balance <= self.accrued_meme_balance) return 0;

    let meme_delta = expected_meme_balance - self.accrued_meme_balance;

    if (meme_delta == 0) return 0;

    let current_meme_reserve = self.meme_reserve.value();

    meme_delta.min(current_meme_reserve)
}

fun provide_liquidity<Meme>(state: &mut AuctionState<Meme>, clock: &Clock) {
    let amount = new_liquidity_amount(state, clock);

    state.accrued_meme_balance = state.accrued_meme_balance + amount;
    state.constant_product.meme_balance_mut().join(state.meme_reserve.split(amount));
}

fun token_cap<Meme>(state: &AuctionState<Meme>): &MemezTokenCap<Meme> {
    state.meme_token_cap.borrow()
}

fun state<Meme>(memez_fun: &mut MemezFun<Auction, Meme>): &AuctionState<Meme> {
    let versioned = memez_fun.versioned_mut();
    maybe_upgrade_state_to_latest(versioned);
    versioned.load_value()
}

fun state_mut<Meme>(memez_fun: &mut MemezFun<Auction, Meme>): &mut AuctionState<Meme> {
    let versioned = memez_fun.versioned_mut();
    maybe_upgrade_state_to_latest(versioned);
    versioned.load_value_mut()
}

#[allow(unused_mut_parameter)]
fun maybe_upgrade_state_to_latest(versioned: &mut Versioned) {
    assert!(
        versioned.version() == AUCTION_STATE_VERSION_V1,
        memez_errors::outdated_auction_state_version(),
    );
}

// === Aliases ===

use fun state as MemezFun.state;
use fun state_mut as MemezFun.state_mut;
use fun destroy_or_burn as Balance.destroy_or_burn;
use fun destroy_or_return as Coin.destroy_or_return;

// === Test Only Functions ===

#[test_only]
public fun start_time<Meme>(self: &mut MemezFun<Auction, Meme>): u64 {
    self.state().start_time
}

#[test_only]
public fun auction_duration<Meme>(self: &mut MemezFun<Auction, Meme>): u64 {
    self.state().auction_duration
}

#[test_only]
public fun initial_reserve<Meme>(self: &mut MemezFun<Auction, Meme>): u64 {
    self.state().initial_reserve
}

#[test_only]
public fun meme_reserve<Meme>(self: &mut MemezFun<Auction, Meme>): u64 {
    self.state().meme_reserve.value()
}

#[test_only]
public fun constant_product<Meme>(self: &mut MemezFun<Auction, Meme>): &MemezConstantProduct<Meme> {
    &self.state().constant_product
}

#[test_only]
public fun dev_allocation<Meme>(self: &mut MemezFun<Auction, Meme>): u64 {
    self.state().dev_allocation.value()
}

#[test_only]
public fun liquidity_provision<Meme>(self: &mut MemezFun<Auction, Meme>): u64 {
    self.state().liquidity_provision.value()
}

#[test_only]
public fun market_cap<Meme>(
    self: &mut MemezFun<Auction, Meme>,
    clock: &Clock,
    decimals: u8,
    total_supply: u64,
): u64 {
    let (_, virtual_price, _) = dump_amount(self, 10u64.pow(decimals), clock);

    u64::mul_div_up(virtual_price, total_supply, 10u64.pow(decimals))
}

#[test_only]
public fun current_meme_balance<Meme>(self: &mut MemezFun<Auction, Meme>, clock: &Clock): u64 {
    meme_balance(self, clock)
}
