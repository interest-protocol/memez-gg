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
#[allow(unused_function)]
module memez_fun::memez_fun;

use ipx_coin_standard::ipx_coin_standard::{MetadataCap, IPXTreasuryStandard};
use memez_fun::{
    memez_allowed_versions::AllowedVersions,
    memez_events,
    memez_metadata::MemezMetadata,
    memez_verifier::{Self, Nonces},
    memez_versioned::Versioned
};
use std::{string::String, type_name::{Self, TypeName}};
use sui::{balance::Balance, clock::Clock, coin::Coin, vec_map::VecMap};

// === Constants ===

const CONFIG_METADATA_KEY: vector<u8> = b"config_key";

// === Structs ===

public enum Progress has copy, drop, store {
    Bonding,
    Migrating,
    Migrated,
}

public struct MemezMigrator<phantom Meme, phantom Quote> {
    witness: TypeName,
    memez_fun: address,
    dev: address,
    quote_balance: Balance<Quote>,
    meme_balance: Balance<Meme>,
}

public struct MemezFun<phantom Curve, phantom Meme, phantom Quote> has key, store {
    id: UID,
    public_key: vector<u8>,
    nonces: Nonces,
    inner_state: address,
    dev: address,
    state: Versioned,
    ipx_meme_coin_treasury: address,
    metadata: MemezMetadata,
    migration_witness: TypeName,
    progress: Progress,
}

// === Public Functions ===

public fun destroy<Meme, Quote, Witness: drop>(
    migrator: MemezMigrator<Meme, Quote>,
    _: Witness,
): (address, Balance<Meme>, Balance<Quote>) {
    let MemezMigrator { witness, memez_fun, meme_balance, quote_balance, dev } = migrator;

    assert!(type_name::get<Witness>() == witness, memez_fun::memez_errors::invalid_witness!());

    memez_events::migrated<Meme, Quote>(
        memez_fun,
        witness,
        quote_balance.value(),
        meme_balance.value(),
    );

    (dev, meme_balance, quote_balance)
}

public fun update_metadata<Curve, Meme, Quote>(
    self: &mut MemezFun<Curve, Meme, Quote>,
    metadata_cap: &MetadataCap,
    mut metadata: VecMap<String, String>,
) {
    assert!(
        metadata_cap.ipx_treasury() == self.ipx_meme_coin_treasury,
        memez_fun::memez_errors::invalid_metadata_cap!(),
    );

    let key = CONFIG_METADATA_KEY.to_string();

    let config_value = self.metadata()[&key];

    metadata.insert(key, config_value);

    self.metadata.update(metadata);
}

// === Public View Functions ===

public fun metadata<Curve, Meme, Quote>(
    self: &MemezFun<Curve, Meme, Quote>,
): VecMap<String, String> {
    *self.metadata.borrow()
}

public fun next_nonce<Curve, Meme, Quote>(self: &MemezFun<Curve, Meme, Quote>, user: address): u64 {
    self.nonces.next_nonce(user)
}

// === Public Package Functions ===

public(package) fun new<Curve, Meme, Quote, ConfigKey, MigrationWitness>(
    state: Versioned,
    public_key: vector<u8>,
    inner_state: address,
    mut metadata: MemezMetadata,
    ipx_meme_coin_treasury: address,
    virtual_liquidity: u64,
    target_quote_liquidity: u64,
    meme_balance: u64,
    total_supply: u64,
    dev: address,
    ctx: &mut TxContext,
): MemezFun<Curve, Meme, Quote> {
    let config_key = type_name::get<ConfigKey>();
    let migration_witness = type_name::get<MigrationWitness>();

    metadata
        .borrow_mut()
        .insert(CONFIG_METADATA_KEY.to_string(), config_key.into_string().to_string());

    let id = object::new(ctx);

    memez_events::new<Curve, Meme, Quote>(
        id.to_address(),
        public_key,
        inner_state,
        dev,
        config_key,
        migration_witness,
        ipx_meme_coin_treasury,
        virtual_liquidity,
        target_quote_liquidity,
        meme_balance,
        total_supply,
    );

    MemezFun {
        id,
        public_key,
        nonces: memez_verifier::new(ctx),
        dev,
        inner_state,
        ipx_meme_coin_treasury,
        metadata,
        migration_witness,
        progress: Progress::Bonding,
        state,
    }
}

public(package) macro fun cp_pump<$Curve, $Meme, $Quote, $State>(
    $self: &mut MemezFun<$Curve, $Meme, $Quote>,
    $f: |&mut MemezFun<$Curve, $Meme, $Quote>| -> &mut $State,
    $quote_coin: Coin<$Quote>,
    $referrer: Option<address>,
    $signature: Option<vector<u8>>,
    $min_amount_out: u64,
    $allowed_versions: AllowedVersions,
    $ctx: &mut TxContext,
): Coin<$Meme> {
    let self = $self;
    let allowed_versions = $allowed_versions;

    allowed_versions.assert_pkg_version();
    self.assert_is_bonding();

    let pool = self.address();
    let public_key = self.public_key();
    let signature = $signature;
    let quote_coin = $quote_coin;

    self.nonces_mut().assert_can_buy(public_key, signature, pool, quote_coin.value(), $ctx);

    self.cp_pump_unchecked!($f, quote_coin, $referrer, $min_amount_out, $ctx)
}

public(package) macro fun cp_pump_unchecked<$Curve, $Meme, $Quote, $State>(
    $self: &mut MemezFun<$Curve, $Meme, $Quote>,
    $f: |&mut MemezFun<$Curve, $Meme, $Quote>| -> &mut $State,
    $quote_coin: Coin<$Quote>,
    $referrer: Option<address>,
    $min_amount_out: u64,
    $ctx: &mut TxContext,
): Coin<$Meme> {
    let self = $self;
    let quote_coin = $quote_coin;
    let min_amount_out = $min_amount_out;
    let ctx = $ctx;

    let state = $f(self);

    let (start_migrating, meme_coin) = state
        .constant_product
        .pump(
            quote_coin,
            $referrer,
            min_amount_out,
            ctx,
        );

    if (start_migrating) self.set_progress_to_migrating();

    meme_coin
}

public(package) macro fun cp_dump<$Curve, $Meme, $Quote, $State>(
    $self: &mut MemezFun<$Curve, $Meme, $Quote>,
    $f: |&mut MemezFun<$Curve, $Meme, $Quote>| -> &mut $State,
    $treasury_cap: &mut IPXTreasuryStandard,
    $meme_coin: Coin<$Meme>,
    $referrer: Option<address>,
    $min_amount_out: u64,
    $allowed_versions: AllowedVersions,
    $ctx: &mut TxContext,
): Coin<$Quote> {
    let self = $self;
    let allowed_versions = $allowed_versions;
    let ctx = $ctx;

    allowed_versions.assert_pkg_version();
    self.assert_is_bonding();

    let state = $f(self);

    state
        .constant_product
        .dump(
            $treasury_cap,
            $meme_coin,
            $referrer,
            $min_amount_out,
            ctx,
        )
}

public(package) macro fun fr_pump<$Curve, $Meme, $Quote, $State>(
    $self: &mut MemezFun<$Curve, $Meme, $Quote>,
    $f: |&mut MemezFun<$Curve, $Meme, $Quote>| -> &mut $State,
    $quote_coin: Coin<$Quote>,
    $referrer: Option<address>,
    $signature: Option<vector<u8>>,
    $allowed_versions: AllowedVersions,
    $ctx: &mut TxContext,
): (Coin<$Quote>, Coin<$Meme>) {
    let self = $self;
    let allowed_versions = $allowed_versions;

    allowed_versions.assert_pkg_version();
    self.assert_is_bonding();
    let pool = self.address();
    let public_key = self.public_key();
    let quote_coin = $quote_coin;

    self.nonces_mut().assert_can_buy(public_key, $signature, pool, quote_coin.value(), $ctx);

    let state = $f(self);

    let (start_migrating, excess_quote_coin, meme_coin) = state
        .fixed_rate
        .pump(
            quote_coin,
            $referrer,
            $ctx,
        );

    if (start_migrating) self.set_progress_to_migrating();

    (excess_quote_coin, meme_coin)
}

public(package) macro fun fr_dump<$Curve, $Meme, $Quote, $State>(
    $self: &mut MemezFun<$Curve, $Meme, $Quote>,
    $f: |&mut MemezFun<$Curve, $Meme, $Quote>| -> &mut $State,
    $meme_coin: Coin<$Meme>,
    $referrer: Option<address>,
    $allowed_versions: AllowedVersions,
    $ctx: &mut TxContext,
): Coin<$Quote> {
    let self = $self;
    let allowed_versions = $allowed_versions;

    allowed_versions.assert_pkg_version();
    self.assert_is_bonding();

    let state = $f(self);

    state
        .fixed_rate
        .dump(
            $meme_coin,
            $referrer,
            $ctx,
        )
}

public(package) macro fun fr_migrate<$Curve, $Meme, $Quote, $State>(
    $self: &mut MemezFun<$Curve, $Meme, $Quote>,
    $f: |&mut MemezFun<$Curve, $Meme, $Quote>| -> &mut $State,
    $allowed_versions: AllowedVersions,
    $ctx: &mut TxContext,
): MemezMigrator<$Meme, $Quote> {
    let self = $self;
    let allowed_versions = $allowed_versions;
    let ctx = $ctx;

    allowed_versions.assert_pkg_version();
    self.assert_is_migrating();

    let state = $f(self);

    let quote_balance = state.fixed_rate.quote_balance_mut().withdraw_all();

    let liquidity_provision = state.liquidity_provision.withdraw_all();

    state.meme_reserve.destroy_or_burn!(ctx);
    state.fixed_rate.meme_balance_mut().destroy_or_burn!(ctx);

    let mut quote_coin = quote_balance.into_coin(ctx);

    state.migration_fee.take(&mut quote_coin, ctx);

    self.migrate(liquidity_provision, quote_coin.into_balance())
}

public(package) macro fun distribute_stake_holders_allocation<$Curve, $Meme, $Quote, $State>(
    $self: &mut MemezFun<$Curve, $Meme, $Quote>,
    $f: |&mut MemezFun<$Curve, $Meme, $Quote>| -> &mut $State,
    $clock: &Clock,
    $allowed_versions: AllowedVersions,
    $ctx: &mut TxContext,
) {
    let self = $self;
    let clock = $clock;
    let allowed_versions = $allowed_versions;
    let ctx = $ctx;

    allowed_versions.assert_pkg_version();
    self.assert_migrated();

    let state = $f(self);

    state.allocation.take(clock, ctx);
}

public(package) macro fun cp_pump_amount<$Curve, $Meme, $Quote, $State>(
    $self: &mut MemezFun<$Curve, $Meme, $Quote>,
    $f: |&mut MemezFun<$Curve, $Meme, $Quote>| -> &$State,
    $amount_in: u64,
): vector<u64> {
    let self = $self;
    let amount_in = $amount_in;

    self.assert_is_bonding();

    let state = $f(self);

    state
        .constant_product
        .pump_amount(
            amount_in,
        )
}

public(package) macro fun cp_dump_amount<$Curve, $Meme, $Quote, $State>(
    $self: &mut MemezFun<$Curve, $Meme, $Quote>,
    $f: |&mut MemezFun<$Curve, $Meme, $Quote>| -> &$State,
    $amount_in: u64,
): vector<u64> {
    let self = $self;
    let amount_in = $amount_in;

    self.assert_is_bonding();

    let state = $f(self);

    state
        .constant_product
        .dump_amount(
            amount_in,
        )
}

public(package) macro fun fr_pump_amount<$Curve, $Meme, $Quote, $State>(
    $self: &mut MemezFun<$Curve, $Meme, $Quote>,
    $f: |&mut MemezFun<$Curve, $Meme, $Quote>| -> (&$State, u64),
    $amount_in: u64,
): vector<u64> {
    let self = $self;
    let amount_in = $amount_in;

    self.assert_is_bonding();

    let (state, extra_meme_sale_amount) = $f(self);

    state
        .fixed_rate
        .pump_amount(
            amount_in,
            extra_meme_sale_amount,
        )
}

public(package) macro fun fr_dump_amount<$Curve, $Meme, $Quote, $State>(
    $self: &mut MemezFun<$Curve, $Meme, $Quote>,
    $f: |&mut MemezFun<$Curve, $Meme, $Quote>| -> (&$State, u64),
    $amount_in: u64,
): vector<u64> {
    let self = $self;
    let amount_in = $amount_in;

    self.assert_is_bonding();

    let (state, extra_meme_sale_amount) = $f(self);

    state
        .fixed_rate
        .dump_amount(
            amount_in,
            extra_meme_sale_amount,
        )
}

public(package) fun addr<Curve, Meme, Quote>(self: &MemezFun<Curve, Meme, Quote>): address {
    self.id.to_address()
}

public(package) fun public_key<Curve, Meme, Quote>(
    self: &MemezFun<Curve, Meme, Quote>,
): vector<u8> {
    self.public_key
}

public(package) fun nonces_mut<Curve, Meme, Quote>(
    self: &mut MemezFun<Curve, Meme, Quote>,
): &mut Nonces {
    &mut self.nonces
}

public(package) fun migration_witness<Curve, Meme, Quote>(
    self: &MemezFun<Curve, Meme, Quote>,
): TypeName {
    self.migration_witness
}

public(package) fun versioned<Curve, Meme, Quote>(self: &MemezFun<Curve, Meme, Quote>): &Versioned {
    &self.state
}

public(package) fun versioned_mut<Curve, Meme, Quote>(
    self: &mut MemezFun<Curve, Meme, Quote>,
): &mut Versioned {
    &mut self.state
}

public(package) fun set_progress_to_migrating<Curve, Meme, Quote>(
    self: &mut MemezFun<Curve, Meme, Quote>,
) {
    self.progress = Progress::Migrating;

    memez_events::can_migrate(self.id.to_address(), self.migration_witness);
}

public(package) fun assert_is_bonding<Curve, Meme, Quote>(self: &MemezFun<Curve, Meme, Quote>) {
    assert!(self.progress == Progress::Bonding, memez_fun::memez_errors::not_bonding!());
}

public(package) fun assert_is_migrating<Curve, Meme, Quote>(self: &MemezFun<Curve, Meme, Quote>) {
    assert!(self.progress == Progress::Migrating, memez_fun::memez_errors::not_migrating!());
}

public(package) fun assert_migrated<Curve, Meme, Quote>(self: &MemezFun<Curve, Meme, Quote>) {
    assert!(self.progress == Progress::Migrated, memez_fun::memez_errors::not_migrated!());
}

public(package) fun assert_is_dev<Curve, Meme, Quote>(
    self: &MemezFun<Curve, Meme, Quote>,
    ctx: &TxContext,
) {
    assert!(self.dev == ctx.sender(), memez_fun::memez_errors::invalid_dev!());
}

// === Public Package Migration Functions ===

public(package) fun migrate<Curve, Meme, Quote>(
    self: &mut MemezFun<Curve, Meme, Quote>,
    meme_balance: Balance<Meme>,
    quote_balance: Balance<Quote>,
): MemezMigrator<Meme, Quote> {
    self.progress = Progress::Migrated;

    MemezMigrator {
        witness: self.migration_witness,
        memez_fun: self.id.to_address(),
        dev: self.dev,
        quote_balance,
        meme_balance,
    }
}

// === Aliases ===

use fun memez_fun::memez_utils::destroy_or_burn as Balance.destroy_or_burn;

public use fun addr as MemezFun.address;

// === Test Only Functions ===

#[test_only]
public fun dev<Curve, Meme, Quote>(self: &MemezFun<Curve, Meme, Quote>): address {
    self.dev
}

#[test_only]
public fun metadata_for_testing<Curve, Meme, Quote>(
    self: &MemezFun<Curve, Meme, Quote>,
): &VecMap<String, String> {
    self.metadata.borrow()
}

#[test_only]
public fun ip_meme_coin_treasury<Curve, Meme, Quote>(self: &MemezFun<Curve, Meme, Quote>): address {
    self.ipx_meme_coin_treasury
}

#[test_only]
public fun new_migrator_for_testing<Meme, Quote, Witness>(
    memez_fun: address,
    dev: address,
    quote_balance: Balance<Quote>,
    meme_balance: Balance<Meme>,
): MemezMigrator<Meme, Quote> {
    MemezMigrator {
        witness: type_name::get<Witness>(),
        memez_fun,
        dev,
        quote_balance,
        meme_balance,
    }
}
