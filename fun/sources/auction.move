module memez_fun::memez_auction;
// === Imports === 

use std::string::String;

use sui::{
    sui::SUI,
    clock::Clock,
    balance::Balance,
    versioned::{Self, Versioned},
    coin::{Coin, TreasuryCap, CoinMetadata},
};

use interest_math::u64;

use ipx_coin_standard::ipx_coin_standard::{IPXTreasuryStandard, MetadataCap};

use memez_fun::{
    memez_auction_config,
    memez_migration::Migration,
    memez_utils::destroy_or_burn,
    memez_version::CurrentVersion,
    memez_config::{Self, MemezConfig},
    memez_fun::{Self, MemezFun, MemezMigrator},
    memez_constant_product::{Self, MemezConstantProduct},
};

// === Constants ===

const AUCTION_STATE_VERSION_V1: u64 = 1;

const POW_9: u64 = 1__000_000_000;

// === Errors === 

#[error]
const EInvalidDev: vector<u8> = b"Invalid dev";

#[error]
const EInvalidVersion: vector<u8> = b"Invalid version";

// === Structs ===

public struct Auction()

public struct AuctionState<phantom Meme> has store {
    start_time: u64, 
    auction_duration: u64,  
    initial_reserve: u64,
    meme_reserve: Balance<Meme>,
    dev_allocation: Balance<Meme>, 
    liquidity_provision: Balance<Meme>, 
    constant_product: MemezConstantProduct<Meme>,
}

// === Public Mutative Functions === 

#[allow(lint(share_owned))]
public fun new<Meme, MigrationWitness>(
    config: &MemezConfig,
    migration: &Migration,
    clock: &Clock, 
    meme_metadata: &CoinMetadata<Meme>,
    meme_treasury_cap: TreasuryCap<Meme>,
    creation_fee: Coin<SUI>,
    metadata_names: vector<String>,
    metadata_values: vector<String>,
    version: CurrentVersion,
    ctx: &mut TxContext
): MetadataCap {
    version.assert_is_valid();
    config.take_creation_fee(creation_fee);

    let auction_config = memez_auction_config::get(config);

    let (ipx_meme_coin_treasury, metadata_cap, mut meme_reserve) = memez_config::set_up_treasury(meme_metadata, meme_treasury_cap, ctx);

    let dev_allocation = meme_reserve.split(auction_config[1]);

    let liquidity_provision = meme_reserve.split(auction_config[5]);

    let meme_balance = meme_reserve.split(auction_config[6]);

    let auction_state = AuctionState<Meme> {
        start_time: clock.timestamp_ms(), 
        auction_duration: auction_config[0], 
        initial_reserve: meme_reserve.value(),
        meme_reserve,
        dev_allocation, 
        liquidity_provision, 
        constant_product: memez_constant_product::new(
            auction_config[3],
            auction_config[4],
            meme_balance,
            auction_config[2]
        ),
    };

    let mut memez_fun = memez_fun::new<Auction, MigrationWitness, Meme>(
        migration, 
        versioned::create(AUCTION_STATE_VERSION_V1, auction_state, ctx), 
        metadata_names, 
        metadata_values, 
        ipx_meme_coin_treasury,
        ctx
    );

    let memez_fun_address = memez_fun.addy();

    let state = state_mut<Meme>(memez_fun.versioned_mut());

    state.constant_product.set_memez_fun(memez_fun_address);

    memez_fun.share();

    metadata_cap
}

public fun pump<Meme>(
    self: &mut MemezFun<Auction,Meme>, 
    clock: &Clock,
    sui_coin: Coin<SUI>, 
    min_amount_out: u64,
    version: CurrentVersion, 
    ctx: &mut TxContext
): Coin<Meme> {
    version.assert_is_valid();
    self.assert_is_bonding();

    let state = state_mut<Meme>(self.versioned_mut());

    state.provide_liquidity(clock);

    let (start_migrating, meme_coin) = state.constant_product.pump(
        sui_coin,
        min_amount_out,
        ctx
    );

    if (start_migrating)
        self.set_progress_to_migrating();

    meme_coin
}

public fun dump<Meme>(
    self: &mut MemezFun<Auction, Meme>, 
    clock: &Clock,
    treasury_cap: &mut IPXTreasuryStandard, 
    meme_coin: Coin<Meme>, 
    min_amount_out: u64,
    version: CurrentVersion, 
    ctx: &mut TxContext
): Coin<SUI> {
    version.assert_is_valid();
    self.assert_is_bonding();

    let state = state_mut<Meme>(self.versioned_mut());

    state.provide_liquidity(clock);

    state.constant_product.dump(
        treasury_cap,
        meme_coin,           
        min_amount_out,
        ctx
    )
}

public fun migrate<Meme>(
    self: &mut MemezFun<Auction, Meme>, 
    config: &MemezConfig,
    version: CurrentVersion, 
    ctx: &mut TxContext
): MemezMigrator<Meme> {
    version.assert_is_valid();
    self.assert_is_migrating();

    let state = state_mut<Meme>(self.versioned_mut());

    let mut sui_balance = state.constant_product.sui_balance_mut().withdraw_all();

    let liquidity_provision = state.liquidity_provision.withdraw_all();

    destroy_or_burn(state.constant_product.meme_balance_mut().withdraw_all().into_coin(ctx));
    destroy_or_burn(state.meme_reserve.withdraw_all().into_coin(ctx));

    config.take_migration_fee(sui_balance.split(config.migration_fee()).into_coin(ctx));

    self.new_migrator(sui_balance, liquidity_provision)
}

public fun dev_claim<Meme>(self: &mut MemezFun<Auction, Meme>, version: CurrentVersion, ctx: &mut TxContext): Coin<Meme> {
    self.assert_migrated();
    assert!(ctx.sender() == self.dev(), EInvalidDev); 

    version.assert_is_valid();

    let state = state_mut<Meme>(self.versioned_mut());

    state.dev_allocation.withdraw_all().into_coin(ctx)
}

// === Public View Functions ===  

public fun meme_price<Meme>(self: &mut MemezFun<Auction, Meme>, clock: &Clock): u64 {
    pump_amount(self, POW_9, clock)
}

public fun pump_amount<Meme>(self: &mut MemezFun<Auction, Meme>, amount_in: u64, clock: &Clock): u64 {
    let state = state<Meme>(self.versioned_mut());

    let amount = new_liquidity_amount(state, clock); 

    state.constant_product.pump_amount(
        amount_in, 
        amount
    )
}

public fun dump_amount<Meme>(self: &mut MemezFun<Auction, Meme>, amount_in: u64, clock: &Clock): (u64, u64) {
    let state = state_mut<Meme>(self.versioned_mut());

    let amount = new_liquidity_amount(state, clock); 

    state.constant_product.dump_amount(amount_in, amount)
}

// === Private Functions === 

fun new_liquidity_amount<Meme>(self: &AuctionState<Meme>, clock: &Clock): u64 {
    let current_time = clock.timestamp_ms(); 

    let meme_balance_value = self.constant_product.meme_balance().value();

    if (current_time - self.start_time > self.auction_duration) return 0;

    let progress = current_time - self.start_time; 

    let percentage = u64::mul_div_up(progress, POW_9, self.auction_duration); 

    let expected_meme_balance = u64::mul_div_up(self.initial_reserve, percentage, POW_9); 

    if (expected_meme_balance <= meme_balance_value) return 0; 

    let meme_delta = expected_meme_balance - meme_balance_value; 

    if (meme_delta == 0) return 0; 

    let current_meme_reserve = self.meme_reserve.value(); 

    u64::min(meme_delta, current_meme_reserve)
}

fun provide_liquidity<Meme>(state: &mut AuctionState<Meme>, clock: &Clock) {
    let amount = new_liquidity_amount(state, clock); 

    state.constant_product.meme_balance_mut().join(state.meme_reserve.split(amount)); 
}

fun state<Meme>(versioned: &mut Versioned): &AuctionState<Meme> {
    maybe_upgrade_state_to_latest(versioned);
    versioned.load_value()
}

fun state_mut<Meme>(versioned: &mut Versioned): &mut AuctionState<Meme> {
    maybe_upgrade_state_to_latest(versioned);
    versioned.load_value_mut()
}

#[allow(unused_mut_parameter)]
fun maybe_upgrade_state_to_latest(versioned: &mut Versioned) {
    assert!(versioned.version() == AUCTION_STATE_VERSION_V1, EInvalidVersion);
}