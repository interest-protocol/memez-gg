module memez_fun::memez_fee_model;

use interest_bps::bps::{Self, BPS};
use memez_fun::{memez_errors, memez_utils};
use sui::coin::Coin;

// === Constants ===

const VALUES_LENGTH: u64 = 3;

// === Structs ===

public struct Recipient has copy, drop, store {
    addy: address,
    bps: BPS,
}

public enum Fee has copy, drop, store {
    Value(u64, vector<Recipient>),
    Percentage(BPS, vector<Recipient>),
}

public struct FeeModel has copy, drop, store {
    new: Fee,
    swap: Fee,
    migration: Fee,
}

// === Public Package Functions ===

public(package) fun new(
    values: vector<vector<u64>>,
    recipients: vector<vector<address>>,
): FeeModel {
    assert!(values.length() == VALUES_LENGTH, memez_errors::invalid_model_config());

    let mut new_percentages = values[0];
    let mut swap_percentages = values[1];
    let mut migration_percentages = values[2];

    let new_value = new_percentages.pop_back();
    let swap_value = swap_percentages.pop_back();
    let migration_value = migration_percentages.pop_back();

    new_percentages.validate();
    swap_percentages.validate();
    migration_percentages.validate();

    FeeModel {
        new: Fee::Value(
            new_value,
            new_percentages.zip_map!(
                recipients[0],
                |bps, addy| Recipient { addy, bps: bps::new(bps) },
            ),
        ),
        swap: Fee::Percentage(
            bps::new(swap_value),
            swap_percentages.zip_map!(
                recipients[1],
                |bps, addy| Recipient { addy, bps: bps::new(bps) },
            ),
        ),
        migration: Fee::Value(
            migration_value,
            migration_percentages.zip_map!(
                recipients[2],
                |bps, addy| Recipient { addy, bps: bps::new(bps) },
            ),
        ),
    }
}

public(package) fun send<T>(fee: Fee, asset: &mut Coin<T>, ctx: &mut TxContext) {
    match (fee) {
        Fee::Value(value, beneficiaries) => {
            if (value == 0) return;

            let payment = asset.split(value, ctx);
            send_internal(payment, beneficiaries, ctx);
        },
        Fee::Percentage(bps, beneficiaries) => {
            if (bps.value() == 0) return;

            let asset_value = asset.value();
            let payment = asset.split(bps.calc(asset_value), ctx);
            send_internal(payment, beneficiaries, ctx);
        },
    };
}

public(package) fun new_fee(self: FeeModel): Fee {
    self.new
}

public(package) fun swap_fee(self: FeeModel): Fee {
    self.swap
}

public(package) fun migration_fee(self: FeeModel): Fee {
    self.migration
}

// === Private Functions === 

fun send_internal<T>(mut payment: Coin<T>, beneficiaries: vector<Recipient>, ctx: &mut TxContext) {
    let payment_value = payment.value();

    beneficiaries.do_ref!(|beneficiary| {
        let current_value = payment.value();
        transfer::public_transfer(
            payment.split(beneficiary.bps.calc(payment_value).min(current_value), ctx),
            beneficiary.addy,
        );
    });

    payment.destroy_or_return(ctx);
}

// === Method Aliases ===

use fun memez_utils::validate_bps as vector.validate;
use fun memez_utils::destroy_or_return as Coin.destroy_or_return;
