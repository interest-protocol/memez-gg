module memez_fun::memez_fees;

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

public struct FeePayload has copy, drop, store {
    value: u64,
    percentages: vector<u64>,
    recipients: vector<address>,
}

public struct MemezFees has copy, drop, store {
    creation: FeePayload,
    swap: FeePayload,
    migration: FeePayload,
}

// === Public Package Functions ===

public(package) fun new(
    values: vector<vector<u64>>,
    recipients: vector<vector<address>>,
): MemezFees {
    assert!(
        values.length() == VALUES_LENGTH && recipients.length() == VALUES_LENGTH,
        memez_errors::invalid_model_config(),
    );

    let mut creation_percentages = values[0];
    let mut swap_percentages = values[1];
    let mut migration_percentages = values[2];

    let creation_value = creation_percentages.pop_back();
    let swap_value = swap_percentages.pop_back();
    let migration_value = migration_percentages.pop_back();

    creation_percentages.validate();
    swap_percentages.validate();
    migration_percentages.validate();

    // @dev We need to add the deployer address to the end of the recipients vector as its a dynamic field
    assert!(
        recipients[1].length() == swap_percentages.length() &&
            recipients[2].length() == migration_percentages.length(),
        memez_errors::wrong_recipients_length(),
    );

    MemezFees {
        creation: FeePayload {
            value: creation_value,
            percentages: creation_percentages,
            recipients: recipients[0],
        },
        swap: FeePayload {
            value: swap_value,
            percentages: swap_percentages,
            recipients: recipients[1],
        },
        migration: FeePayload {
            value: migration_value,
            percentages: migration_percentages,
            recipients: recipients[2],
        },
    }
}

public(package) fun calculate(fee: Fee, amount_in: u64): u64 {
    match (fee) {
        Fee::Value(value, _) => value,
        Fee::Percentage(bps, _) => bps.calc(amount_in),
    }
}

public(package) fun take<T>(fee: Fee, asset: &mut Coin<T>, ctx: &mut TxContext): u64 {
    match (fee) {
        Fee::Value(value, beneficiaries) => {
            if (value == 0) return 0;

            let payment = asset.split(value, ctx);
            let payment_value = payment.value();
            take_internal(payment, beneficiaries, ctx);

            payment_value
        },
        Fee::Percentage(bps, beneficiaries) => {
            if (bps.value() == 0) return 0;

            let asset_value = asset.value();
            let payment = asset.split(bps.calc(asset_value), ctx);
            let payment_value = payment.value();
            take_internal(payment, beneficiaries, ctx);

            payment_value
        },
    }
}

public(package) fun creation(self: MemezFees): Fee {
    Fee::Value(
        self.creation.value,
        self
            .creation
            .percentages
            .zip_map!(self.creation.recipients, |bps, addy| Recipient { addy, bps: bps::new(bps) }),
    )
}

public(package) fun swap(self: MemezFees, dev: address): Fee {
    let mut recipients = self.swap.recipients;

    recipients.push_back(dev);

    Fee::Percentage(
        bps::new(self.swap.value),
        recipients.zip_map!(
            self.swap.percentages,
            |addy, bps| Recipient { addy, bps: bps::new(bps) },
        ),
    )
}

public(package) fun migration(self: MemezFees, dev: address): Fee {
    let mut recipients = self.migration.recipients;

    recipients.push_back(dev);

    Fee::Value(
        self.migration.value,
        recipients.zip_map!(
            self.migration.percentages,
            |addy, bps| Recipient { addy, bps: bps::new(bps) },
        ),
    )
}

// === Private Functions ===

fun take_internal<T>(mut payment: Coin<T>, beneficiaries: vector<Recipient>, ctx: &mut TxContext) {
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

// === Test Functions ===

#[test_only]
public fun new_recipient(addy: address, bps: u64): Recipient {
    Recipient { addy, bps: bps::new(bps) }
}

#[test_only]
public fun new_value_fee(value: u64, recipients: vector<Recipient>): Fee {
    Fee::Value(value, recipients)
}

#[test_only]
public fun new_percentage_fee(value: u64, recipients: vector<Recipient>): Fee {
    Fee::Percentage(bps::new(value), recipients)
}
