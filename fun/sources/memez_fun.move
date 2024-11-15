module memez_fun::memez_fun;
// === Imports === 

use std::{
    string::String,
    type_name::{Self, TypeName},
};

use sui::{
    sui::SUI,
    clock::Clock,
    vec_map::{Self, VecMap},
    balance::{Self, Balance},
    coin::{Coin, TreasuryCap, CoinMetadata},
};

use interest_math::u64;

use ipx_coin_standard::ipx_coin_standard::{Self, IPXTreasuryStandard, MetadataCap};

use memez_invariant::memez_invariant::get_amount_out;

use memez_fun::{
    memez_events,
    memez_config::MemezConfig,
    memez_migration::Migration,
    memez_version::CurrentVersion,
};

// === Constants ===

const POW_9: u64 = 1__000_000_000;

const TOTAL_MEME_SUPPLY: u64 = 1_000_000_000__000_000_000;

const DEAD_ADDRESS: address = @0x0;

// === Errors === 

#[error]
const EWrongDecimals: vector<u8> = b"Meme coins must have 9 decimals"; 

#[error]
const EPreMint: vector<u8> = b"Meme treasury cap must have no supply"; 

#[error]
const EZeroCoin: vector<u8> = b"Coin value must be greater than 0"; 

#[error]
const EMigrating: vector<u8> = b"Pool is migrating"; 

#[error] 
const ENotMigrating: vector<u8> = b"Pool is not migrating";

#[error]
const EInvalidWitness: vector<u8> = b"Invalid witness";

#[error]
const EInvalidDev: vector<u8> = b"Invalid dev";

#[error]
const EInvalidDevClaim: vector<u8> = b"Invalid dev claim";

// === Structs ===

public struct MemezMigrator<phantom Meme> {
    witness: TypeName, 
    memez_fun: address,
    sui_balance: Balance<SUI>,
    meme_balance: Balance<Meme>,  
}

public struct MemezFun<phantom Meme> has key {
    id: UID,
    start_time: u64, 
    auction_duration: u64, 
    burn_tax: u64,  
    virtual_liquidity: u64, 
    target_sui_liquidity: u64,  
    initial_reserve: u64,
    sui_balance: Balance<SUI>,
    meme_reserve: Balance<Meme>,
    meme_balance: Balance<Meme>, 
    dev_allocation: Balance<Meme>, 
    liquidity_provision: Balance<Meme>, 
    metadata: VecMap<String, String>,
    dev: address,
    is_migrating: bool,
    migration_witness: TypeName,
}

// === Public Mutative Functions === 

#[allow(lint(share_owned))]
public fun new<Meme, MigrationWitness>(
    config: &MemezConfig,
    migration: &Migration,
    clock: &Clock, 
    meme_metadata: &CoinMetadata<Meme>,
    mut meme_treasury_cap: TreasuryCap<Meme>,
    creation_fee: Coin<SUI>,
    metadata_names: vector<String>,
    metadata_values: vector<String>,
    version: CurrentVersion,
    ctx: &mut TxContext
): MetadataCap {
    version.assert_is_valid();
    config.take_creation_fee(creation_fee);

    assert!(meme_metadata.get_decimals() == 9, EWrongDecimals); 
    assert!(meme_treasury_cap.total_supply() == 0, EPreMint); 

    let migration_witness = type_name::get<MigrationWitness>(); 

    migration.assert_is_whitelisted(migration_witness);

    let (
        auction_duration,
        dev_allocation,
        burn_tax,
        virtual_liquidity,
        target_sui_liquidity,
        liquidity_provision,
    ) = config.get();

    let mut meme_reserve = meme_treasury_cap.mint(TOTAL_MEME_SUPPLY, ctx).into_balance(); 

    let dev_allocation = meme_reserve.split(dev_allocation);

    let liquidity_provision = meme_reserve.split(liquidity_provision);

    let meme_balance = meme_reserve.split(POW_9 * 10);

    let memez_fun = MemezFun<Meme> {
        id: object::new(ctx),
        start_time: clock.timestamp_ms(), 
        auction_duration, 
        burn_tax,  
        virtual_liquidity, 
        target_sui_liquidity,  
        initial_reserve: meme_reserve.value(),
        sui_balance: balance::zero(),
        meme_reserve,
        meme_balance, 
        dev_allocation, 
        liquidity_provision, 
        metadata: vec_map::from_keys_values(metadata_names, metadata_values),
        is_migrating: false,
        dev: ctx.sender(),
        migration_witness,
    };

    memez_events::new<Meme>(memez_fun.id.to_address(), migration_witness);

    let (mut ipx_treasury_standard, mut cap_witness) = ipx_coin_standard::new(meme_treasury_cap, ctx);

    cap_witness.add_burn_capability(&mut ipx_treasury_standard);

    transfer::share_object(memez_fun);
    transfer::public_share_object(ipx_treasury_standard);

    cap_witness.create_metadata_cap(ctx)
}

public fun pump<Meme>(
    self: &mut MemezFun<Meme>, 
    clock: &Clock,
    sui_coin: Coin<SUI>, 
    version: CurrentVersion, 
    ctx: &mut TxContext
): Coin<Meme> {
    version.assert_is_valid();

    assert!(!self.is_migrating, EMigrating);

    self.provide_liquidity(clock);

    let sui_coin_value = sui_coin.value(); 

    assert!(sui_coin_value != 0, EZeroCoin);

    let meme_balance_value = self.meme_balance.value();

    let meme_coin_value_out = get_amount_out(
        sui_coin_value, 
        self.virtual_liquidity + self.sui_balance.value(), 
        meme_balance_value
    );

    let meme_coin = self.meme_balance.split(meme_coin_value_out).into_coin(ctx);

    let total_sui_balance = self.sui_balance.join(sui_coin.into_balance());  

    let memez_fun_address = self.id.to_address();

    if (total_sui_balance >= self.target_sui_liquidity) {
        self.is_migrating = true; 
        memez_events::can_migrate(memez_fun_address, self.migration_witness);
    };

    memez_events::pump<Meme>(memez_fun_address, sui_coin_value, meme_coin_value_out);

    meme_coin
}

public fun dump<Meme>(
    self: &mut MemezFun<Meme>, 
    clock: &Clock,
    treasury_cap: &mut IPXTreasuryStandard, 
    mut meme_coin: Coin<Meme>, 
    version: CurrentVersion, 
    ctx: &mut TxContext
): Coin<SUI> {
    version.assert_is_valid();

    assert!(!self.is_migrating, EMigrating);

    self.provide_liquidity(clock);

    let meme_coin_value = meme_coin.value();

    assert!(meme_coin_value != 0, EZeroCoin);

    let meme_balance_value = self.meme_balance.value();

    let sui_balance_value = self.sui_balance.value(); 

    let sui_virtual_liquidity = self.virtual_liquidity + sui_balance_value;

    let pre_tax_sui_value_out = get_amount_out(
        meme_coin_value, 
        meme_balance_value, 
        sui_virtual_liquidity
    ); 

    let dynamic_burn_tax = self.get_dynamic_burn_tax(sui_virtual_liquidity - pre_tax_sui_value_out);

    let meme_fee_value = u64::mul_div_up(meme_coin_value, dynamic_burn_tax, POW_9);

    treasury_cap.burn(meme_coin.split(meme_fee_value, ctx));

    let post_tax_sui_value_out = get_amount_out(
        meme_coin_value - meme_fee_value, 
        meme_balance_value, 
        sui_virtual_liquidity
    );

    memez_events::dump<Meme>(self.id.to_address(), post_tax_sui_value_out, meme_coin_value, meme_fee_value);

    self.meme_balance.join(meme_coin.into_balance()); 

    self.sui_balance.split(post_tax_sui_value_out).into_coin(ctx)
}

public fun migrate<Meme>(
    self: &mut MemezFun<Meme>, 
    config: &MemezConfig,
    version: CurrentVersion, 
    ctx: &mut TxContext
): MemezMigrator<Meme> {
    version.assert_is_valid();

    assert!(self.is_migrating, ENotMigrating); 

    let mut sui_balance = self.sui_balance.withdraw_all();

    let liquidity_provision = self.liquidity_provision.withdraw_all();

    destroy_or_burn(self.meme_balance.withdraw_all().into_coin(ctx));
    destroy_or_burn(self.meme_reserve.withdraw_all().into_coin(ctx));

    let migration_fee = config.migration_fee();

    config.take_migration_fee(sui_balance.split(migration_fee).into_coin(ctx));

    MemezMigrator<Meme> { 
        witness: self.migration_witness, 
        memez_fun: self.id.to_address(), 
        sui_balance, 
        meme_balance: liquidity_provision 
    }
}

public fun destroy<Meme, Witness: drop>(migrator: MemezMigrator<Meme>, _: Witness): (Balance<SUI>, Balance<Meme>) {
    let MemezMigrator { witness, memez_fun, sui_balance, meme_balance } = migrator;

    assert!(type_name::get<Witness>() == witness, EInvalidWitness);

    memez_events::migrated(memez_fun, witness, sui_balance.value(), meme_balance.value());

    (sui_balance, meme_balance)
}

public fun dev_claim<Meme>(self: &mut MemezFun<Meme>, version: CurrentVersion, ctx: &mut TxContext): Coin<Meme> {
    assert!(ctx.sender() == self.dev, EInvalidDev); 
    assert!(self.is_migrating, EInvalidDevClaim);
    
    version.assert_is_valid();

    self.dev_allocation.withdraw_all().into_coin(ctx)
}

// === Public View Functions ===  

public fun meme_price<Meme>(self: &MemezFun<Meme>, clock: &Clock): u64 {
    self.pump_amount( POW_9, clock)
}

public fun pump_amount<Meme>(self: &MemezFun<Meme>, amount_in: u64, clock: &Clock): u64 {
    let amount = self.new_liquidity_amount(clock); 

    get_amount_out(
        amount_in, 
        self.virtual_liquidity + self.sui_balance.value(), 
        self.meme_balance.value() + amount
    )
}

public fun dump_amount<Meme>(self: &MemezFun<Meme>, amount_in: u64, clock: &Clock): (u64, u64) {
    let amount = self.new_liquidity_amount(clock); 

    let meme_balance_value = self.meme_balance.value() + amount;

    let sui_balance_value = self.sui_balance.value(); 

    let sui_virtual_liquidity = self.virtual_liquidity + sui_balance_value;

    let pre_tax_sui_value_out = get_amount_out(
        amount_in, 
        meme_balance_value, 
        sui_virtual_liquidity
    ); 

    let dynamic_burn_tax = self.get_dynamic_burn_tax(sui_virtual_liquidity - pre_tax_sui_value_out);

    let meme_fee_value = u64::mul_div_up(amount_in, dynamic_burn_tax, POW_9);

    let post_tax_sui_value_out = get_amount_out(
        amount_in - meme_fee_value, 
        meme_balance_value, 
        sui_virtual_liquidity
    );

    (post_tax_sui_value_out, meme_fee_value)
}

// === Private Functions === 

fun new_liquidity_amount<Meme>(self: &MemezFun<Meme>, clock: &Clock): u64 {
    let current_time = clock.timestamp_ms(); 

    if (current_time - self.start_time > self.auction_duration) return 0;

    let progress = current_time - self.start_time; 

    let percentage = u64::mul_div_up(progress, POW_9, self.auction_duration); 

    let expected_meme_balance = u64::mul_div_up(self.initial_reserve, percentage, POW_9); 

    let meme_balance_value = self.meme_balance.value();  

    if (expected_meme_balance <= meme_balance_value) return 0; 

    let meme_delta = expected_meme_balance - meme_balance_value; 

    if (meme_delta == 0) return 0; 

    let current_meme_reserve = self.meme_reserve.value(); 

    u64::min(meme_delta, current_meme_reserve)
}

fun provide_liquidity<Meme>(self: &mut MemezFun<Meme>, clock: &Clock) {
    let amount = self.new_liquidity_amount( clock); 

    self.meme_balance.join(self.meme_reserve.split(amount)); 
}

fun get_dynamic_burn_tax<Meme>(
    self: &MemezFun<Meme>, 
    liquidity: u64
): u64 {
    if (liquidity >= self.target_sui_liquidity) return 0; 

    if (self.virtual_liquidity >= liquidity) return self.burn_tax; 

    let total_range = self.target_sui_liquidity - self.virtual_liquidity;  

    let progress = liquidity - self.virtual_liquidity;  

    let remaining_percentage = u64::mul_div_down(total_range - progress, POW_9, total_range);    

    u64::mul_div_up(self.burn_tax, remaining_percentage, POW_9)
}

fun destroy_or_burn<Meme>(coin: Coin<Meme>) {
    if (coin.value() == 0)
        coin.destroy_zero()
    else 
        transfer::public_transfer(coin, DEAD_ADDRESS);
}