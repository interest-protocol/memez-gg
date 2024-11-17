module memez_fun::memez_pump;
// === Imports === 

use std::string::String;

use sui::{
    sui::SUI,
    balance::{Self, Balance},
    versioned::{Self, Versioned},
    coin::{Coin, TreasuryCap, CoinMetadata},
};

use ipx_coin_standard::ipx_coin_standard::{IPXTreasuryStandard, MetadataCap};

use memez_fun::{
    memez_pump_config,
    memez_migration::Migration,
    memez_version::CurrentVersion,
    memez_config::{Self, MemezConfig},
    memez_utils::{destroy_or_burn, pow_9},
    memez_fun::{Self, MemezFun, MemezMigrator},
    memez_constant_product::{Self, MemezConstantProduct},
};

// === Constants ===

const PUMP_STATE_VERSION_V1: u64 = 1;

// === Errors ===

#[error]
const EInvalidVersion: vector<u8> = b"Invalid version";

// === Structs ===

public struct Pump()

public struct PumpState<phantom Meme> has store {
    dev_purchase: Balance<Meme>, 
    liquidity_provision: Balance<Meme>, 
    constant_product: MemezConstantProduct<Meme>,
}

// === Public Mutative Functions === 

#[allow(lint(share_owned))]
public fun new<Meme, MigrationWitness>(
    config: &MemezConfig,
    migration: &Migration,
    meme_metadata: &CoinMetadata<Meme>,
    meme_treasury_cap: TreasuryCap<Meme>,
    creation_fee: Coin<SUI>,
    first_purchase: Coin<SUI>,
    metadata_names: vector<String>,
    metadata_values: vector<String>,
    version: CurrentVersion,
    ctx: &mut TxContext
): MetadataCap {
    version.assert_is_valid();
    config.take_creation_fee(creation_fee);

    let pump_config = memez_pump_config::get(config);

    let (ipx_meme_coin_treasury, metadata_cap, mut meme_balance) = memez_config::set_up_treasury(meme_metadata, meme_treasury_cap, ctx);

    let liquidity_provision = meme_balance.split(pump_config[3]);

    let pump_state = PumpState<Meme> {
        dev_purchase: balance::zero(), 
        liquidity_provision, 
        constant_product: memez_constant_product::new(
            pump_config[1],
            pump_config[2],
            meme_balance,
            pump_config[0]
        ),
    };

    let mut memez_fun = memez_fun::new<Pump, MigrationWitness, Meme>(
        migration, 
        versioned::create(PUMP_STATE_VERSION_V1, pump_state, ctx), 
        metadata_names, 
        metadata_values, 
        ipx_meme_coin_treasury,
        ctx
    );

    if (first_purchase.value() != 0) {
        let meme_coin = pump(&mut memez_fun, first_purchase, 0, version, ctx);

        let state = state_mut<Meme>(memez_fun.versioned_mut());

        state.dev_purchase.join(meme_coin.into_balance());
    } else {
        first_purchase.destroy_zero();
    };

    memez_fun.share();

    metadata_cap
}

public fun pump<Meme>(
    self: &mut MemezFun<Pump,Meme>, 
    sui_coin: Coin<SUI>, 
    min_amount_out: u64,
    version: CurrentVersion, 
    ctx: &mut TxContext
): Coin<Meme> {
    version.assert_is_valid();
    self.assert_is_bonding();

    let (start_migrating, meme_coin) = state_mut<Meme>(self.versioned_mut()).constant_product.pump(
        sui_coin,
        min_amount_out,
        ctx
    );

    if (start_migrating)
        self.set_progress_to_migrating();

    meme_coin
}

public fun dump<Meme>(
    self: &mut MemezFun<Pump, Meme>, 
    treasury_cap: &mut IPXTreasuryStandard, 
    meme_coin: Coin<Meme>, 
    min_amount_out: u64,
    version: CurrentVersion, 
    ctx: &mut TxContext
): Coin<SUI> {
    version.assert_is_valid();
    self.assert_is_bonding();

    state_mut<Meme>(self.versioned_mut()).constant_product.dump(
        treasury_cap,
        meme_coin,           
        min_amount_out,
        ctx
    )
}

public fun migrate<Meme>(
    self: &mut MemezFun<Pump, Meme>, 
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

    config.take_migration_fee(sui_balance.split(config.migration_fee()).into_coin(ctx));

    self.new_migrator(sui_balance, liquidity_provision)
}

public fun dev_claim<Meme>(self: &mut MemezFun<Pump, Meme>, version: CurrentVersion, ctx: &mut TxContext): Coin<Meme> {
    self.assert_migrated();
    self.assert_is_dev(ctx); 

    version.assert_is_valid();

    let state = state_mut<Meme>(self.versioned_mut());

    state.dev_purchase.withdraw_all().into_coin(ctx)
}

// === Public View Functions ===  

public fun meme_price<Meme>(self: &mut MemezFun<Pump, Meme>): u64 {
    pump_amount(self, pow_9())
}

public fun pump_amount<Meme>(self: &mut MemezFun<Pump, Meme>, amount_in: u64): u64 {
    let state = state<Meme>(self.versioned_mut());

    state.constant_product.pump_amount(
        amount_in, 
        0
    )
}

public fun dump_amount<Meme>(self: &mut MemezFun<Pump, Meme>, amount_in: u64): (u64, u64) {
    let state = state_mut<Meme>(self.versioned_mut());

    state.constant_product.dump_amount(amount_in, 0)
}

// === Private Functions === 

fun state<Meme>(versioned: &mut Versioned): &PumpState<Meme> {
    maybe_upgrade_state_to_latest(versioned);
    versioned.load_value()
}

fun state_mut<Meme>(versioned: &mut Versioned): &mut PumpState<Meme> {
    maybe_upgrade_state_to_latest(versioned);
    versioned.load_value_mut()
}

#[allow(unused_mut_parameter)]
fun maybe_upgrade_state_to_latest(versioned: &mut Versioned) {
    assert!(versioned.version() == PUMP_STATE_VERSION_V1, EInvalidVersion);
}