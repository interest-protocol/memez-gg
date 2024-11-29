module memez_fun::memez_config;

use interest_bps::bps;
use ipx_coin_standard::ipx_coin_standard::{Self, MetadataCap};
use memez_acl::acl::AuthWitness;
use memez_fun::{memez_errors, memez_fee_model::{Self, FeeModel}};
use std::type_name;
use sui::{balance::Balance, coin::TreasuryCap, dynamic_field as df};

// === Structs ===

public struct StandardFeeModelKey() has copy, drop, store;

public struct MemezConfig has key {
    id: UID,
    treasury: address,
}

// === Initializer ===

fun init(ctx: &mut TxContext) {
    let config = MemezConfig {
        id: object::new(ctx),
        treasury: @treasury,
    };

    transfer::share_object(config);
}

// === Public Admin Functions ===

public fun set_fee_model<ModelKey>(
    self: &mut MemezConfig,
    _: &AuthWitness,
    values: vector<vector<u64>>,
    recipients: vector<vector<address>>,
    _ctx: &mut TxContext,
) {
    let mut new_percentages = values[0];
    let mut swap_percentages = values[1];
    let mut migration_percentages = values[2];

    let new_value = new_percentages.pop_back();
    let swap_value = swap_percentages.pop_back();
    let migration_value = migration_percentages.pop_back();

    let fee_model = memez_fee_model::new(
        memez_fee_model::fee_value(new_value, new_percentages.map!(|x| bps::new(x)), recipients[0]),
        memez_fee_model::fee_percentage(
            bps::new(swap_value),
            swap_percentages.map!(|x| bps::new(x)),
            recipients[1],
        ),
        memez_fee_model::fee_value(
            migration_value,
            migration_percentages.map!(|x| bps::new(x)),
            recipients[2],
        ),
    );

    let key = type_name::get<ModelKey>();

    df::remove_if_exists<_, FeeModel>(&mut self.id, key);

    df::add(&mut self.id, key, fee_model);
}

public fun set_treasury(self: &mut MemezConfig, _: &AuthWitness, treasury: address) {
    self.treasury = treasury;
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

public(package) fun uid(self: &MemezConfig): &UID {
    &self.id
}

public(package) fun uid_mut(self: &mut MemezConfig): &mut UID {
    &mut self.id
}

public(package) fun get_model<ModelKey>(self: &MemezConfig): FeeModel {
    *df::borrow<_, FeeModel>(&self.id, type_name::get<ModelKey>())
}

// === Tests Only Functions ===

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}

#[test_only]
public fun treasury(self: &MemezConfig): address {
    self.treasury
}
