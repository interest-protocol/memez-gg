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

use interest_bps::bps::{Self, max_bps};
use interest_math::u64;
use ipx_coin_standard::ipx_coin_standard::{IPXTreasuryStandard, MetadataCap};
use memez_fun::{
    memez_config::MemezConfig,
    memez_constant_product::{Self, MemezConstantProduct},
    memez_errors,
    memez_fees::Fee,
    memez_fun::{Self, MemezFun, MemezMigrator},
    memez_migrator_list::MemezMigratorList,
    memez_token_cap::{Self, MemezTokenCap},
    memez_utils::{destroy_or_burn, destroy_or_return, new_treasury},
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
    migration_fee: Fee,
    auction_duration: u64,
    initial_reserve: u64,
    accrued_meme_balance: u64,
    allocation_fee: Fee,
    meme_reserve: Balance<Meme>,
    dev_allocation: Balance<Meme>,
    liquidity_provision: Balance<Meme>,
    stake_holders_allocation: Balance<Meme>,
    constant_product: MemezConstantProduct<Meme>,
    meme_token_cap: Option<MemezTokenCap<Meme>>,
}

// === Public Mutative Functions ===

#[allow(lint(share_owned))]
public fun new<Meme, ConfigKey, MigrationWitness>(
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
    dev: address,
    version: CurrentVersion,
    ctx: &mut TxContext,
): MetadataCap {
    version.assert_is_valid();

    let fees = config.fees<ConfigKey>();

    fees.creation().take(&mut creation_fee, ctx);

    creation_fee.destroy_or_return(ctx);

    let auction_config = config.get_auction<ConfigKey>(total_supply);

    let meme_token_cap = if (is_token) option::some(memez_token_cap::new(&meme_treasury_cap, ctx))
    else option::none();

    let (ipx_meme_coin_treasury, metadata_cap, mut meme_reserve) = new_treasury(
        meme_treasury_cap,
        total_supply,
        ctx,
    );

    let dev_allocation = meme_reserve.split(auction_config[1]);

    let liquidity_provision = meme_reserve.split(auction_config[5]);

    let meme_balance = meme_reserve.split(auction_config[6]);

    let stake_holders_allocation = meme_reserve.split(auction_config[7]);

    let stake_holders_vesting_period = auction_config[8];

    let auction_state = AuctionState<Meme> {
        start_time: clock.timestamp_ms(),
        auction_duration: auction_config[0],
        initial_reserve: meme_reserve.value(),
        accrued_meme_balance: 0,
        meme_reserve,
        dev_allocation,
        liquidity_provision,
        allocation_fee: fees.allocation(stake_holders, stake_holders_vesting_period),
        constant_product: memez_constant_product::new(
            auction_config[3],
            auction_config[4],
            meme_balance,
            fees.swap(stake_holders),
            auction_config[2],
        ),
        stake_holders_allocation,
        meme_token_cap,
        migration_fee: fees.migration(stake_holders),
    };

    let mut memez_fun = memez_fun::new<Auction, Meme, ConfigKey, MigrationWitness>(
        migrator_list,
        versioned::create(AUCTION_STATE_VERSION_V1, auction_state, ctx),
        is_token,
        metadata_names,
        metadata_values,
        ipx_meme_coin_treasury,
        dev,
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
    sui_coin: Coin<SUI>,
    min_amount_out: u64,
    version: CurrentVersion,
    ctx: &mut TxContext,
): Coin<Meme> {
    self.cp_pump!<Auction, Meme, AuctionState<Meme>>(|self| {
        let state = self.state_mut();
        state.drip(clock);
        state
    }, sui_coin, min_amount_out, version, ctx)
}

public fun pump_token<Meme>(
    self: &mut MemezFun<Auction, Meme>,
    clock: &Clock,
    sui_coin: Coin<SUI>,
    min_amount_out: u64,
    version: CurrentVersion,
    ctx: &mut TxContext,
): Token<Meme> {
    self.cp_pump_token!(|self| {
        let state = self.state_mut();
        state.drip(clock);
        state
    }, sui_coin, min_amount_out, version, ctx)
}

public fun dump<Meme>(
    self: &mut MemezFun<Auction, Meme>,
    clock: &Clock,
    treasury_cap: &mut IPXTreasuryStandard,
    meme_coin: Coin<Meme>,
    min_amount_out: u64,
    version: CurrentVersion,
    ctx: &mut TxContext,
): Coin<SUI> {
    self.cp_dump!(|self| {
        let state = self.state_mut();
        state.drip(clock);
        state
    }, treasury_cap, meme_coin, min_amount_out, version, ctx)
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
    self.cp_dump_token!(|self| {
        let state = self.state_mut();
        state.drip(clock);
        state
    }, treasury_cap, meme_token, min_amount_out, version, ctx)
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

    state.migration_fee.take(&mut sui_coin, ctx);

    self.migrate(sui_coin.into_balance(), liquidity_provision)
}

public fun dev_allocation_claim<Meme>(
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

public fun distribute_stake_holders_allocation<Meme>(
    self: &mut MemezFun<Auction, Meme>,
    clock: &Clock,
    version: CurrentVersion,
    ctx: &mut TxContext,
) {
    self.distribute_stake_holders_allocation!(|self| self.state_mut(), clock, version, ctx)
}

public fun to_coin<Meme>(
    self: &mut MemezFun<Auction, Meme>,
    meme_token: Token<Meme>,
    ctx: &mut TxContext,
): Coin<Meme> {
    self.to_coin!(|self| self.state_mut(), meme_token, ctx)
}

// === View Functions for FE ===

#[allow(unused_function)]
fun pump_amount<Meme>(
    self: &mut MemezFun<Auction, Meme>,
    amount_in: u64,
    clock: &Clock,
): vector<u64> {
    let state = self.state();

    let amount = state.expected_drip_amount(clock);

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
): vector<u64> {
    let state = self.state();

    let amount = state.expected_drip_amount(clock);

    state.constant_product.dump_amount(amount_in, amount)
}

#[allow(unused_function)]
fun meme_balance<Meme>(self: &mut MemezFun<Auction, Meme>, clock: &Clock): u64 {
    let state = self.state();

    let amount = state.expected_drip_amount(clock);

    state.constant_product.meme_balance().value() + amount
}

// === Private Functions ===

fun expected_drip_amount<Meme>(self: &AuctionState<Meme>, clock: &Clock): u64 {
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

fun drip<Meme>(state: &mut AuctionState<Meme>, clock: &Clock) {
    let amount = state.expected_drip_amount(clock);

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
    let amounts = dump_amount(self, 10u64.pow(decimals), clock);

    u64::mul_div_up(amounts[1], total_supply, 10u64.pow(decimals))
}

#[test_only]
public fun current_meme_balance<Meme>(self: &mut MemezFun<Auction, Meme>, clock: &Clock): u64 {
    meme_balance(self, clock)
}
