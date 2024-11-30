module memez_fun::memez_config;

use ipx_coin_standard::ipx_coin_standard::{Self, MetadataCap};
use memez_acl::acl::AuthWitness;
use memez_fun::{
    memez_auction_model::{Self, AuctionModel},
    memez_burn_model::{Self, BurnModel},
    memez_errors,
    memez_fee_model::{Self, FeeModel},
    memez_pump_model::{Self, PumpModel},
    memez_stable_model::{Self, StableModel}
};
use std::type_name;
use sui::{balance::Balance, coin::TreasuryCap, dynamic_field as df};

// === Structs ===

public struct DefaultModelKey() has copy, drop, store;

public struct FeeModelKey<phantom T>() has copy, drop, store;

public struct BurnModelKey<phantom T>() has copy, drop, store;

public struct AuctionModelKey<phantom T>() has copy, drop, store;

public struct PumpModelKey<phantom T>() has copy, drop, store;

public struct StableModelKey<phantom T>() has copy, drop, store;

public struct MemezConfig has key {
    id: UID,
}

// === Initializer ===

fun init(ctx: &mut TxContext) {
    let config = MemezConfig {
        id: object::new(ctx),
    };

    transfer::share_object(config);
}

// === Public Admin Functions ===

public fun set_fee_model<T>(
    self: &mut MemezConfig,
    _: &AuthWitness,
    values: vector<vector<u64>>,
    recipients: vector<vector<address>>,
    _ctx: &mut TxContext,
) {
    add<FeeModelKey<T>, _>(self, memez_fee_model::new(values, recipients));
}

public fun set_burn_model<T>(
    self: &mut MemezConfig,
    _: &AuthWitness,
    values: vector<u64>,
    _ctx: &mut TxContext,
) {
    add<BurnModelKey<T>, _>(self, memez_burn_model::new(values));
}

public fun set_auction_model<T>(
    self: &mut MemezConfig,
    _: &AuthWitness,
    values: vector<u64>,
    _ctx: &mut TxContext,
) {
    add<AuctionModelKey<T>, _>(self, memez_auction_model::new(values));
}

public fun set_pump_model<T>(
    self: &mut MemezConfig,
    _: &AuthWitness,
    values: vector<u64>,
    _ctx: &mut TxContext,
) {
    add<PumpModelKey<T>, _>(self, memez_pump_model::new(values));
}

public fun set_stable_model<T>(
    self: &mut MemezConfig,
    _: &AuthWitness,
    values: vector<u64>,
    _ctx: &mut TxContext,
) {
    add<StableModelKey<T>, _>(self, memez_stable_model::new(values));
}

public fun remove_model<T, Model: drop + store>(
    self: &mut MemezConfig,
    _: &AuthWitness,
    _ctx: &mut TxContext,
) {
    df::remove_if_exists<_, Model>(&mut self.id, type_name::get<T>());
}

// === Public Package Functions ===

#[allow(lint(share_owned))]
public(package) fun set_up_meme_treasury<Meme>(
    mut meme_treasury_cap: TreasuryCap<Meme>,
    total_supply: u64,
    ctx: &mut TxContext,
): (address, MetadataCap, Balance<Meme>) {
    assert!(meme_treasury_cap.total_supply() == 0, memez_errors::pre_mint_not_allowed());

    let meme_balance = meme_treasury_cap.mint_balance(
        total_supply,
    );

    let (mut ipx_treasury_standard, mut cap_witness) = ipx_coin_standard::new(
        meme_treasury_cap,
        ctx,
    );

    cap_witness.add_burn_capability(
        &mut ipx_treasury_standard,
    );

    let treasury_address = object::id_address(
        &ipx_treasury_standard,
    );

    transfer::public_share_object(
        ipx_treasury_standard,
    );

    (treasury_address, cap_witness.create_metadata_cap(ctx), meme_balance)
}

public(package) fun fee_model<T>(self: &MemezConfig): FeeModel {
    self.model<FeeModelKey<T>, _>()
}

public(package) fun burn_model<T>(self: &MemezConfig): BurnModel {
    self.model<BurnModelKey<T>, _>()
}

public(package) fun get_auction<T>(self: &MemezConfig, total_supply: u64): vector<u64> {
    self.get!<AuctionModelKey<T>, AuctionModel>(total_supply)
}

public(package) fun get_pump<T>(self: &MemezConfig, total_supply: u64): vector<u64> {
    self.get!<PumpModelKey<T>, PumpModel>(total_supply)
}

public(package) fun get_stable<T>(self: &MemezConfig, total_supply: u64): vector<u64> {
    self.get!<StableModelKey<T>, StableModel>(total_supply)
}

// === Private Functions ===

fun model<Key, Model: store + copy>(self: &MemezConfig): Model {
    assert!(
        df::exists_with_type<_, Model>(&self.id, type_name::get<Key>()),
        memez_errors::model_key_not_supported(),
    );

    *df::borrow(&self.id, type_name::get<Key>())
}

macro fun get<$Key, $Model>($self: &MemezConfig, $total_supply: u64): _ {
    let self = $self;
    let total_supply = $total_supply;

    assert!(
        df::exists_with_type<_, $Model>(&self.id, type_name::get<$Key>()),
        memez_errors::model_key_not_supported(),
    );

    df::borrow<_, $Model>(&self.id, type_name::get<$Key>()).get(total_supply)
}

fun add<ModelKey, Model: drop + store>(self: &mut MemezConfig, model: Model) {
    let key = type_name::get<ModelKey>();

    df::remove_if_exists<_, Model>(&mut self.id, key);

    df::add(&mut self.id, key, model);
}

// === Tests Only Functions ===

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}
