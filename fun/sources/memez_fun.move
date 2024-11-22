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

use memez_fun::{memez_events, memez_migrator_list::MemezMigratorList};
use std::{string::String, type_name::{Self, TypeName}};
use sui::{balance::Balance, sui::SUI, vec_map::{Self, VecMap}, versioned::Versioned};

// === Errors ===

#[error]
const ENotBonding: vector<u8> = b"Memez is not bonding";

#[error]
const ENotMigrating: vector<u8> = b"Memez is not migrating";

#[error]
const ENotMigrated: vector<u8> = b"Memez is not migrated";

#[error]
const EInvalidWitness: vector<u8> = b"Invalid witness";

#[error]
const EInvalidDev: vector<u8> = b"Invalid dev";

#[error]
const ETokenNotSupported: vector<u8> = b"Token not supported";

#[error]
const ETokenSupported: vector<u8> = b"Token already supported";

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

public struct MemezFun<phantom Curve, phantom Meme> has key {
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

    assert!(type_name::get<Witness>() == witness, EInvalidWitness);

    memez_events::migrated(memez_fun, witness, sui_balance.value(), meme_balance.value());

    (sui_balance, meme_balance)
}

// === Public Package Functions ===

public(package) fun new<Curve, MigrationWitness, Meme>(
    migrator: &MemezMigratorList,
    state: Versioned,
    is_token: bool,
    metadata_names: vector<String>,
    metadata_values: vector<String>,
    ipx_meme_coin_treasury: address,
    ctx: &mut TxContext,
): MemezFun<Curve, Meme> {
    let migration_witness = type_name::get<MigrationWitness>();

    migrator.assert_is_whitelisted(migration_witness);

    let id = object::new(ctx);

    memez_events::new<Curve, Meme>(
        id.to_address(),
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

public(package) fun share<Curve, Meme>(self: MemezFun<Curve, Meme>) {
    transfer::share_object(self);
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
    assert!(self.progress == Progress::Bonding, ENotBonding);
}

public(package) fun assert_is_migrating<Curve, Meme>(self: &MemezFun<Curve, Meme>) {
    assert!(self.progress == Progress::Migrating, ENotMigrating);
}

public(package) fun assert_migrated<Curve, Meme>(self: &MemezFun<Curve, Meme>) {
    assert!(self.progress == Progress::Migrated, ENotMigrated);
}

public(package) fun assert_is_dev<Curve, Meme>(self: &MemezFun<Curve, Meme>, ctx: &TxContext) {
    assert!(self.dev == ctx.sender(), EInvalidDev);
}

public(package) fun assert_uses_token<Curve, Meme>(self: &MemezFun<Curve, Meme>) {
    assert!(self.is_token, ETokenNotSupported);
}

public(package) fun assert_uses_coin<Curve, Meme>(self: &MemezFun<Curve, Meme>) {
    assert!(!self.is_token, ETokenSupported);
}

// === Public Package Migration Functions ===

public(package) fun new_migrator<Curve, Meme>(
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
