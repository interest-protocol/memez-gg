module memez_fun::memez_fee_model;

use interest_bps::bps::BPS;
use memez_fun::memez_utils;
use sui::coin::Coin;

// === Structs ===

public struct Recipient has store, copy, drop {
    addy: address,
    bps: BPS,
}

public enum Fee has store, copy, drop {
    Value(u64, vector<Recipient>),
    Percentage(BPS, vector<Recipient>),
}

public struct FeeModel has store, copy, drop {
    new: Fee,
    swap: Fee,
    migration: Fee,
}

// === Public Package Functions ===

public(package) fun new(new: Fee, swap: Fee, migration: Fee): FeeModel {
    FeeModel {
        new,
        swap,
        migration,
    }
}

public(package) fun fee_value(value: u64, percentages: vector<BPS>, addys: vector<address>): Fee {
    percentages.validate();

    Fee::Value(
        value,
        addys.zip_map!(percentages, |addy, bps| Recipient { addy, bps }),
    )
}

public(package) fun fee_percentage(
    value: BPS,
    percentages: vector<BPS>,
    addys: vector<address>,
): Fee {
    percentages.validate();

    Fee::Percentage(
        value,
        addys.zip_map!(percentages, |addy, bps| Recipient { addy, bps }),
    )
}

public(package) fun send<T>(fee: Fee, asset: &mut Coin<T>, ctx: &mut TxContext) {
    let (mut payment, beneficiaries) = match (fee) {
        Fee::Value(value, beneficiaries) => (asset.split(value, ctx), beneficiaries),
        Fee::Percentage(value, beneficiaries) => {
            let asset_value = asset.value();

            (asset.split(value.calc(asset_value), ctx), beneficiaries)
        },
    };

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

public(package) fun new_fee(self: FeeModel): Fee {
    self.new
}

public(package) fun swap_fee(self: FeeModel): Fee {
    self.swap
}

public(package) fun migration_fee(self: FeeModel): Fee {
    self.migration
}

// === Method Aliases ===

use fun memez_utils::validate_bps as vector.validate;
use fun memez_utils::destroy_or_return as Coin.destroy_or_return;
