module memez_fun::memez_auction;
// === Imports === 

use std::string::String;

use sui::{
    sui::SUI,
    clock::Clock,
    balance::{Self, Balance},
    versioned::{Self, Versioned},
    coin::{Coin, TreasuryCap, CoinMetadata},
};

use interest_math::u64;

use ipx_coin_standard::ipx_coin_standard::{IPXTreasuryStandard, MetadataCap};

use constant_product::constant_product::get_amount_out;

use memez_fun::{
    memez_events,
    memez_auction_config,
    memez_migration::Migration,
    memez_version::CurrentVersion,
    memez_config::{Self, MemezConfig},
    memez_fun::{Self, MemezFun, MemezMigrator},
    memez_utils::{assert_slippage, destroy_or_burn},
};

// === Constants ===

const STATE_VERSION_V1: u64 = 1;

const POW_9: u64 = 1__000_000_000;

// === Errors === 

#[error]
const EZeroCoin: vector<u8> = b"Coin value must be greater than 0"; 

#[error]
const EInvalidDev: vector<u8> = b"Invalid dev";

#[error]
const EInvalidVersion: vector<u8> = b"Invalid version";

// === Structs ===

public struct Auction()

public struct AuctionState<phantom Meme> has store {
    start_time: u64, 
    auction_duration: u64, 
    burn_tax: u64,  
    sui_balance: Balance<SUI>,
    meme_balance: Balance<Meme>,
    virtual_liquidity: u64, 
    target_sui_liquidity: u64,  
    initial_reserve: u64,
    meme_reserve: Balance<Meme>,
    dev_allocation: Balance<Meme>, 
    liquidity_provision: Balance<Meme>, 
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

    let (metadata_cap, mut meme_reserve) = memez_config::set_up_treasury(meme_metadata, meme_treasury_cap, ctx);

    let dev_allocation = meme_reserve.split(auction_config[1]);

    let liquidity_provision = meme_reserve.split(auction_config[5]);

    let meme_balance = meme_reserve.split(auction_config[6]);

    let auction_state = AuctionState<Meme> {
        start_time: clock.timestamp_ms(), 
        auction_duration: auction_config[0], 
        burn_tax: auction_config[2],  
        virtual_liquidity: auction_config[3], 
        target_sui_liquidity: auction_config[4],  
        initial_reserve: meme_reserve.value(),
        meme_reserve,
        dev_allocation, 
        liquidity_provision, 
        sui_balance: balance::zero(),
        meme_balance,
    };

    let memez_fun = memez_fun::new<Auction, MigrationWitness, Meme>(
        migration, 
        versioned::create(STATE_VERSION_V1, auction_state, ctx), 
        metadata_names, 
        metadata_values, 
        ctx
    );

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

    let sui_coin_value = sui_coin.value(); 

    assert!(sui_coin_value != 0, EZeroCoin);

    let meme_balance_value = state.meme_balance.value();

    let meme_coin_value_out = get_amount_out(
        sui_coin_value, 
        state.virtual_liquidity + state.sui_balance.value(), 
        meme_balance_value
    );

    assert_slippage(meme_coin_value_out, min_amount_out);

    let meme_coin = state.meme_balance.split(meme_coin_value_out).into_coin(ctx);

    let total_sui_balance = state.sui_balance.join(sui_coin.into_balance());  

    if (total_sui_balance >= state.target_sui_liquidity)
        self.set_progress_to_migrating();

    memez_events::pump<Meme>(self.addy(), sui_coin_value, meme_coin_value_out);

    meme_coin
}

public fun dump<Meme>(
    self: &mut MemezFun<Auction, Meme>, 
    clock: &Clock,
    treasury_cap: &mut IPXTreasuryStandard, 
    mut meme_coin: Coin<Meme>, 
    min_amount_out: u64,
    version: CurrentVersion, 
    ctx: &mut TxContext
): Coin<SUI> {
    version.assert_is_valid();
    self.assert_is_bonding();

    let state = state_mut<Meme>(self.versioned_mut());

    state.provide_liquidity(clock);

    let meme_coin_value = meme_coin.value();

    assert!(meme_coin_value != 0, EZeroCoin);

    let meme_balance_value = state.meme_balance.value();

    let sui_balance_value = state.sui_balance.value(); 

    let sui_virtual_liquidity = state.virtual_liquidity + sui_balance_value;

    let pre_tax_sui_value_out = get_amount_out(
        meme_coin_value, 
        meme_balance_value, 
        sui_virtual_liquidity
    ); 

    let dynamic_burn_tax = state.get_dynamic_burn_tax(sui_virtual_liquidity - pre_tax_sui_value_out);

    let meme_fee_value = u64::mul_div_up(meme_coin_value, dynamic_burn_tax, POW_9);

    treasury_cap.burn(meme_coin.split(meme_fee_value, ctx));

    let post_tax_sui_value_out = get_amount_out(
        meme_coin_value - meme_fee_value, 
        meme_balance_value, 
        sui_virtual_liquidity
    );

    state.meme_balance.join(meme_coin.into_balance()); 

    let sui_coin_amount_out = u64::min(post_tax_sui_value_out, sui_balance_value);

    assert_slippage(sui_coin_amount_out, min_amount_out);

    let sui_coin = state.sui_balance.split(sui_coin_amount_out).into_coin(ctx);

    memez_events::dump<Meme>(
        self.addy(), 
        post_tax_sui_value_out, 
        meme_coin_value, 
        meme_fee_value
    );

    sui_coin
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

    let mut sui_balance = state.sui_balance.withdraw_all();

    let liquidity_provision = state.liquidity_provision.withdraw_all();

    destroy_or_burn(state.meme_balance.withdraw_all().into_coin(ctx));
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

    let amount = new_liquidity_amount(state, clock, state.meme_balance.value()); 

    get_amount_out(
        amount_in, 
        state.virtual_liquidity + state.sui_balance.value(), 
        state.meme_balance.value() + amount
    )
}

public fun dump_amount<Meme>(self: &mut MemezFun<Auction, Meme>, amount_in: u64, clock: &Clock): (u64, u64) {
    let state = state_mut<Meme>(self.versioned_mut());

    let amount = new_liquidity_amount(state, clock, state.meme_balance.value()); 

    let meme_balance_value = state.meme_balance.value() + amount;

    let sui_balance_value = state.sui_balance.value(); 

    let sui_virtual_liquidity = state.virtual_liquidity + sui_balance_value;

    let pre_tax_sui_value_out = get_amount_out(
        amount_in, 
        meme_balance_value, 
        sui_virtual_liquidity
    ); 

    let dynamic_burn_tax = state.get_dynamic_burn_tax(sui_virtual_liquidity - pre_tax_sui_value_out);

    let meme_fee_value = u64::mul_div_up(amount_in, dynamic_burn_tax, POW_9);

    let post_tax_sui_value_out = get_amount_out(
        amount_in - meme_fee_value, 
        meme_balance_value, 
        sui_virtual_liquidity
    );

    (u64::min(post_tax_sui_value_out, sui_balance_value), meme_fee_value)
}

// === Private Functions === 

fun new_liquidity_amount<Meme>(self: &AuctionState<Meme>, clock: &Clock, meme_balance_value: u64): u64 {
    let current_time = clock.timestamp_ms(); 

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
    let amount = new_liquidity_amount(state, clock, state.meme_balance.value()); 

    state.meme_balance.join(state.meme_reserve.split(amount)); 
}

fun get_dynamic_burn_tax<Meme>(
    self: &AuctionState<Meme>, 
    liquidity: u64
): u64 {
    if (liquidity >= self.target_sui_liquidity) return 0; 

    if (self.virtual_liquidity >= liquidity) return self.burn_tax; 

    let total_range = self.target_sui_liquidity - self.virtual_liquidity;  

    let progress = liquidity - self.virtual_liquidity;  

    let remaining_percentage = u64::mul_div_down(total_range - progress, POW_9, total_range);    

    u64::mul_div_up(self.burn_tax, remaining_percentage, POW_9)
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
    assert!(versioned.version() == STATE_VERSION_V1, EInvalidVersion);
}