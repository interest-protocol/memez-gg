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
module memez_fun::memez_fun;

use ipx_coin_standard::ipx_coin_standard::IPXTreasuryStandard;
use memez_fun::{
    memez_allowed_versions::AllowedVersions,
    memez_errors,
    memez_events,
    memez_migrator_list::MemezMigratorList,
    memez_versioned::Versioned
};
use std::{string::String, type_name::{Self, TypeName}};
use sui::{
    bag::{Self, Bag},
    balance::Balance,
    clock::Clock,
    coin::Coin,
    token::Token,
    vec_map::{Self, VecMap}
};

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
    quote_balance: Balance<Quote>,
    meme_balance: Balance<Meme>,
}

public struct MemezFun<phantom Curve, phantom Meme> has key {
    id: UID,
    dev: address,
    is_token: bool,
    state: Versioned,
    ipx_meme_coin_treasury: address,
    metadata: VecMap<String, String>,
    migration_witness: TypeName,
    progress: Progress,
    // Extra fields for future use
    extra_fields: Bag,
}

// === Public Functions ===

public fun destroy<Meme, Quote, Witness: drop>(
    migrator: MemezMigrator<Meme, Quote>,
    _: Witness,
): (Balance<Quote>, Balance<Meme>) {
    let MemezMigrator { witness, memez_fun, quote_balance, meme_balance } = migrator;

    assert!(type_name::get<Witness>() == witness, memez_errors::invalid_witness!());

    memez_events::migrated<Meme, Quote>(memez_fun, witness, quote_balance.value(), meme_balance.value());

    (quote_balance, meme_balance)
}

// === Public Package Functions ===

public(package) fun new<Curve, Meme, Quote, ConfigKey, MigrationWitness>(
    migrator: &MemezMigratorList,
    state: Versioned,
    is_token: bool,
    inner_state: address,
    mut metadata_names: vector<String>,
    mut metadata_values: vector<String>,
    ipx_meme_coin_treasury: address,
    virtual_liquidity: u64,
    target_quote_liquidity: u64,
    meme_balance: u64,
    dev: address,
    ctx: &mut TxContext,
): MemezFun<Curve, Meme> {
    let config_key = type_name::get<ConfigKey>();
    let migration_witness = type_name::get<MigrationWitness>();

    migrator.assert_is_whitelisted(migration_witness);

    metadata_names.push_back(CONFIG_METADATA_KEY.to_string());
    metadata_values.push_back(config_key.into_string().to_string());

    let id = object::new(ctx);

    memez_events::new<Curve, Meme, Quote>(
        id.to_address(),
        inner_state,
        config_key,
        migration_witness,
        ipx_meme_coin_treasury,
        virtual_liquidity,
        target_quote_liquidity,
        meme_balance,
    );

    MemezFun {
        id,
        dev,
        is_token,
        ipx_meme_coin_treasury,
        metadata: vec_map::from_keys_values(metadata_names, metadata_values),
        migration_witness,
        progress: Progress::Bonding,
        state,
        extra_fields: bag::new(ctx),
    }
}

public(package) macro fun cp_pump<$Curve, $Meme, $Quote, $State>(
    $self: &mut MemezFun<$Curve, $Meme>,
    $f: |&mut MemezFun<$Curve, $Meme>| -> &mut $State,
    $quote_coin: Coin<$Quote>,
    $min_amount_out: u64,
    $allowed_versions: AllowedVersions,
    $ctx: &mut TxContext,
): Coin<$Meme> {
    let self = $self;
    let allowed_versions = $allowed_versions;

    allowed_versions.assert_pkg_version();
    self.assert_uses_coin();
    self.assert_is_bonding();

    self.cp_pump_unchecked!($f, $quote_coin, $min_amount_out, $ctx)
}

public(package) macro fun cp_pump_unchecked<$Curve, $Meme, $Quote, $State>(
    $self: &mut MemezFun<$Curve, $Meme>,
    $f: |&mut MemezFun<$Curve, $Meme>| -> &mut $State,
    $quote_coin: Coin<$Quote>,
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
            min_amount_out,
            ctx,
        );

    if (start_migrating) self.set_progress_to_migrating();

    meme_coin
}

public(package) macro fun cp_pump_token<$Curve, $Meme, $Quote, $State>(
    $self: &mut MemezFun<$Curve, $Meme>,
    $f: |&mut MemezFun<$Curve, $Meme>| -> &mut $State,
    $quote_coin: Coin<$Quote>,
    $min_amount_out: u64,
    $allowed_versions: AllowedVersions,
    $ctx: &mut TxContext,
): Token<$Meme> {
    let self = $self;
    let allowed_versions = $allowed_versions;
    let ctx = $ctx;

    let quote_coin = $quote_coin;
    let min_amount_out = $min_amount_out;

    allowed_versions.assert_pkg_version();
    self.assert_uses_token();
    self.assert_is_bonding();

    let state = $f(self);

    let (start_migrating, meme_coin) = state
        .constant_product
        .pump(
            quote_coin,
            min_amount_out,
            ctx,
        );

    let meme_token = state.token_cap().from_coin(meme_coin, ctx);

    if (start_migrating) self.set_progress_to_migrating();

    meme_token
}

public(package) macro fun cp_dump<$Curve, $Meme, $Quote, $State>(
    $self: &mut MemezFun<$Curve, $Meme>,
    $f: |&mut MemezFun<$Curve, $Meme>| -> &mut $State,
    $treasury_cap: &mut IPXTreasuryStandard,
    $meme_coin: Coin<$Meme>,
    $min_amount_out: u64,
    $allowed_versions: AllowedVersions,
    $ctx: &mut TxContext,
): Coin<$Quote> {
    let self = $self;
    let allowed_versions = $allowed_versions;
    let ctx = $ctx;

    allowed_versions.assert_pkg_version();
    self.assert_uses_coin();
    self.assert_is_bonding();

    let treasury_cap = $treasury_cap;
    let meme_coin = $meme_coin;
    let min_amount_out = $min_amount_out;

    let state = $f(self);

    state
        .constant_product
        .dump(
            treasury_cap,
            meme_coin,
            min_amount_out,
            ctx,
        )
}

public(package) macro fun cp_dump_token<$Curve, $Meme, $Quote, $State>(
    $self: &mut MemezFun<$Curve, $Meme>,
    $f: |&mut MemezFun<$Curve, $Meme>| -> &mut $State,
    $treasury_cap: &mut IPXTreasuryStandard,
    $meme_token: Token<$Meme>,
    $min_amount_out: u64,
    $allowed_versions: AllowedVersions,
    $ctx: &mut TxContext,
): Coin<$Quote> {
    let self = $self;
    let allowed_versions = $allowed_versions;
    let ctx = $ctx;

    allowed_versions.assert_pkg_version();
    self.assert_uses_token();
    self.assert_is_bonding();

    let treasury_cap = $treasury_cap;
    let meme_token = $meme_token;
    let min_amount_out = $min_amount_out;

    let state = $f(self);

    let meme_coin = state.token_cap().to_coin(meme_token, ctx);

    state
        .constant_product
        .dump(
            treasury_cap,
            meme_coin,
            min_amount_out,
            ctx,
        )
}

public(package) macro fun to_coin<$Curve, $Meme, $State>(
    $self: &mut MemezFun<$Curve, $Meme>,
    $f: |&mut MemezFun<$Curve, $Meme>| -> &mut $State,
    $meme_token: Token<$Meme>,
    $ctx: &mut TxContext,
): Coin<$Meme> {
    let self = $self;
    let meme_token = $meme_token;
    let ctx = $ctx;

    self.assert_migrated();

    $f(self).token_cap().to_coin(meme_token, ctx)
}

public(package) macro fun distribute_stake_holders_allocation<$Curve, $Meme, $State>(
    $self: &mut MemezFun<$Curve, $Meme>,
    $f: |&mut MemezFun<$Curve, $Meme>| -> &mut $State,
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

public(package) macro fun cp_pump_amount<$Curve, $Meme, $State>(
    $self: &mut MemezFun<$Curve, $Meme>,
    $f: |&mut MemezFun<$Curve, $Meme>| -> (&$State, u64),
    $amount_in: u64,
): vector<u64> {
    let amount_in = $amount_in;

    let (state, amount) = $f($self);

    state
        .constant_product
        .pump_amount(
            amount_in,
            amount,
        )
}

public(package) macro fun cp_dump_amount<$Curve, $Meme, $State>(
    $self: &mut MemezFun<$Curve, $Meme>,
    $f: |&mut MemezFun<$Curve, $Meme>| -> (&$State, u64),
    $amount_in: u64,
): vector<u64> {
    let amount_in = $amount_in;

    let (state, amount) = $f($self);

    state
        .constant_product
        .dump_amount(
            amount_in,
            amount,
        )
}

public(package) fun share<Curve, Meme>(self: MemezFun<Curve, Meme>) {
    transfer::share_object(self);
}

public(package) fun addy<Curve, Meme>(self: &MemezFun<Curve, Meme>): address {
    self.id.to_address()
}

public(package) fun migration_witness<Curve, Meme>(self: &MemezFun<Curve, Meme>): TypeName {
    self.migration_witness
}

public(package) fun versioned<Curve, Meme>(self: &MemezFun<Curve, Meme>): &Versioned {
    &self.state
}

public(package) fun versioned_mut<Curve, Meme>(self: &mut MemezFun<Curve, Meme>): &mut Versioned {
    &mut self.state
}

public(package) fun set_progress_to_migrating<Curve, Meme>(self: &mut MemezFun<Curve, Meme>) {
    self.progress = Progress::Migrating;

    memez_events::can_migrate(self.id.to_address(), self.migration_witness);
}

public(package) fun assert_is_bonding<Curve, Meme>(self: &MemezFun<Curve, Meme>) {
    assert!(self.progress == Progress::Bonding, memez_errors::not_bonding!());
}

public(package) fun assert_is_migrating<Curve, Meme>(self: &MemezFun<Curve, Meme>) {
    assert!(self.progress == Progress::Migrating, memez_errors::not_migrating!());
}

public(package) fun assert_migrated<Curve, Meme>(self: &MemezFun<Curve, Meme>) {
    assert!(self.progress == Progress::Migrated, memez_errors::not_migrated!());
}

public(package) fun assert_is_dev<Curve, Meme>(self: &MemezFun<Curve, Meme>, ctx: &TxContext) {
    assert!(self.dev == ctx.sender(), memez_errors::invalid_dev!());
}

public(package) fun assert_uses_token<Curve, Meme>(self: &MemezFun<Curve, Meme>) {
    assert!(self.is_token, memez_errors::token_not_supported!());
}

public(package) fun assert_uses_coin<Curve, Meme>(self: &MemezFun<Curve, Meme>) {
    assert!(!self.is_token, memez_errors::token_supported!());
}

// === Public Package Migration Functions ===

public(package) fun migrate<Curve, Meme, Quote>(
    self: &mut MemezFun<Curve, Meme>,
    quote_balance: Balance<Quote>,
    meme_balance: Balance<Meme>,
): MemezMigrator<Meme, Quote> {
    self.progress = Progress::Migrated;

    MemezMigrator {
        witness: self.migration_witness,
        memez_fun: self.id.to_address(),
        quote_balance,
        meme_balance,
    }
}

#[test_only]
public fun dev<Curve, Meme>(self: &MemezFun<Curve, Meme>): address {
    self.dev
}

#[test_only]
public fun metadata<Curve, Meme>(self: &MemezFun<Curve, Meme>): &VecMap<String, String> {
    &self.metadata
}

#[test_only]
public fun ip_meme_coin_treasury<Curve, Meme>(self: &MemezFun<Curve, Meme>): address {
    self.ipx_meme_coin_treasury
}

#[test_only]
public fun new_migrator_for_testing<Meme, Quote, Witness>(
    memez_fun: address,
    quote_balance: Balance<Quote>,
    meme_balance: Balance<Meme>,
): MemezMigrator<Meme, Quote> {
    MemezMigrator {
        witness: type_name::get<Witness>(),
        memez_fun,
        quote_balance,
        meme_balance,
    }
}
