module memez_fun::memez_pump;
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
    memez_pump_config,
    memez_migration::Migration,
    memez_version::CurrentVersion,
    memez_burn_tax::{Self, BurnTax},
    memez_config::{Self, MemezConfig},
    memez_fun::{Self, MemezFun, MemezMigrator},
    memez_utils::{assert_slippage, destroy_or_burn, assert_coin_has_value},
};

// === Constants ===

const PUMP_STATE_VERSION_V1: u64 = 1;

// === Structs ===

public struct Pump()

public struct PumpState<phantom Meme> has store {
    burn_tax: BurnTax,  
    sui_balance: Balance<SUI>,
    meme_balance: Balance<Meme>,
    virtual_liquidity: u64, 
    target_sui_liquidity: u64,  
    dev_purchase: Balance<Meme>, 
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

    let pump_config = memez_pump_config::get(config);

    let (ipx_meme_coin_treasury, metadata_cap, mut meme_balance) = memez_config::set_up_treasury(meme_metadata, meme_treasury_cap, ctx);

    let liquidity_provision = meme_balance.split(pump_config[3]);

    let pump_state = PumpState<Meme> {
        burn_tax: memez_burn_tax::new(pump_config[0], pump_config[1], pump_config[2]),  
        virtual_liquidity: pump_config[1], 
        target_sui_liquidity: pump_config[2],  
        dev_purchase: balance::zero(), 
        liquidity_provision, 
        sui_balance: balance::zero(),
        meme_balance,
    };

    let memez_fun = memez_fun::new<Pump, MigrationWitness, Meme>(
        migration, 
        versioned::create(PUMP_STATE_VERSION_V1, pump_state, ctx), 
        metadata_names, 
        metadata_values, 
        ipx_meme_coin_treasury,
        ctx
    );

    memez_fun.share();

    metadata_cap
}