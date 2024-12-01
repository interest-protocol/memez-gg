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

use memez_fun::{memez_errors, memez_events, memez_migrator_list::MemezMigratorList};
use std::{string::String, type_name::{Self, TypeName}};
use sui::{balance::Balance, sui::SUI, vec_map::{Self, VecMap}, versioned::Versioned};

// === Structs ===

public enum Progress has store, drop, copy {
    Bonding,
    Migrating,
    Migrated,
}

public struct MemezMigrator<phantom Meme> {
    witness: TypeName,
    memez_fun: address,
    sui_balance: Balance<SUI>,
    meme_balance: Balance<Meme>,
}

public struct MemezFun<phantom Curve, phantom Meme> has key, store {
    id: UID,
    dev: address,
    is_token: bool,
    state: Versioned,
    ipx_meme_coin_treasury: address,
    metadata: VecMap<String, String>,
    migration_witness: TypeName,
    progress: Progress,
}

// === Public Functions ===

public fun destroy<Meme, Witness: drop>(
    migrator: MemezMigrator<Meme>,
    _: Witness,
): (Balance<SUI>, Balance<Meme>) {
    let MemezMigrator { witness, memez_fun, sui_balance, meme_balance } = migrator;

    assert!(type_name::get<Witness>() == witness, memez_errors::invalid_witness());

    memez_events::migrated(memez_fun, witness, sui_balance.value(), meme_balance.value());

    (sui_balance, meme_balance)
}

// === Public Package Functions ===

public(package) fun new<Curve, Meme, ConfigKey, MigrationWitness>(
    migrator: &MemezMigratorList,
    state: Versioned,
    is_token: bool,
    mut metadata_names: vector<String>,
    mut metadata_values: vector<String>,
    ipx_meme_coin_treasury: address,
    ctx: &mut TxContext,
): MemezFun<Curve, Meme> {
    let config_key = type_name::get<ConfigKey>();
    let migration_witness = type_name::get<MigrationWitness>();

    migrator.assert_is_whitelisted(migration_witness);

    metadata_names.push_back(b"config_key".to_string());
    metadata_values.push_back(config_key.into_string().to_string());

    let id = object::new(ctx);

    memez_events::new<Curve, Meme>(
        id.to_address(),
        config_key,
        migration_witness,
        ipx_meme_coin_treasury,
    );

    MemezFun {
        id,
        dev: ctx.sender(),
        is_token,
        ipx_meme_coin_treasury,
        metadata: vec_map::from_keys_values(metadata_names, metadata_values),
        migration_witness,
        progress: Progress::Bonding,
        state,
    }
}

#[allow(lint(share_owned))]
public(package) fun share<Curve, Meme>(self: MemezFun<Curve, Meme>) {
    transfer::public_share_object(self);
}

public(package) fun addy<Curve, Meme>(self: &MemezFun<Curve, Meme>): address {
    self.id.to_address()
}

public(package) fun migration_witness<Curve, Meme>(self: &MemezFun<Curve, Meme>): TypeName {
    self.migration_witness
}

public(package) fun dev<Curve, Meme>(self: &MemezFun<Curve, Meme>): address {
    self.dev
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
    assert!(self.progress == Progress::Bonding, memez_errors::not_bonding());
}

public(package) fun assert_is_migrating<Curve, Meme>(self: &MemezFun<Curve, Meme>) {
    assert!(self.progress == Progress::Migrating, memez_errors::not_migrating());
}

public(package) fun assert_migrated<Curve, Meme>(self: &MemezFun<Curve, Meme>) {
    assert!(self.progress == Progress::Migrated, memez_errors::not_migrated());
}

public(package) fun assert_is_dev<Curve, Meme>(self: &MemezFun<Curve, Meme>, ctx: &TxContext) {
    assert!(self.dev == ctx.sender(), memez_errors::invalid_dev());
}

public(package) fun assert_uses_token<Curve, Meme>(self: &MemezFun<Curve, Meme>) {
    assert!(self.is_token, memez_errors::token_not_supported());
}

public(package) fun assert_uses_coin<Curve, Meme>(self: &MemezFun<Curve, Meme>) {
    assert!(!self.is_token, memez_errors::token_supported());
}

// === Public Package Migration Functions ===

public(package) fun migrate<Curve, Meme>(
    self: &mut MemezFun<Curve, Meme>,
    sui_balance: Balance<SUI>,
    meme_balance: Balance<Meme>,
): MemezMigrator<Meme> {
    self.progress = Progress::Migrated;

    MemezMigrator {
        witness: self.migration_witness,
        memez_fun: self.id.to_address(),
        sui_balance,
        meme_balance,
    }
}

#[test_only]
public fun metadata<Curve, Meme>(self: &MemezFun<Curve, Meme>): &VecMap<String, String> {
    &self.metadata
}

#[test_only]
public fun ip_meme_coin_treasury<Curve, Meme>(self: &MemezFun<Curve, Meme>): address {
    self.ipx_meme_coin_treasury
}
