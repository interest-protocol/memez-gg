module memez_fun::memez_fees;

use interest_bps::bps::{Self, BPS};
use memez_fun::{memez_distributor::{Self, Distributor}, memez_errors, memez_utils};
use sui::{balance::{Self, Balance}, clock::Clock, coin::Coin};

// === Constants ===

const VALUES_LENGTH: u64 = 4;

// === Structs ===

public enum Fee has copy, drop, store {
    Value(u64, Distributor),
    Percentage(BPS, Distributor),
}

public struct FeePayload has copy, drop, store {
    value: u64,
    percentages: vector<u64>,
    recipients: vector<address>,
}

public struct Allocation<phantom T> has store {
    balance: Balance<T>,
    vesting_period: u64,
    distributor: Distributor,
}

public struct MemezFees has copy, drop, store {
    creation: FeePayload,
    swap: FeePayload,
    migration: FeePayload,
    allocation: FeePayload,
    vesting_period: u64,
}

// === Public Package Functions ===

public(package) fun new(
    values: vector<vector<u64>>,
    recipients: vector<vector<address>>,
): MemezFees {
    assert!(
        values.length() == VALUES_LENGTH && recipients.length() == VALUES_LENGTH,
        memez_errors::invalid_config(),
    );

    let mut creation_percentages = values[0];
    let mut swap_percentages = values[1];
    let mut migration_percentages = values[2];
    let mut allocation_percentages = values[3];

    let creation_value = creation_percentages.pop_back();
    let swap_value = swap_percentages.pop_back();
    let migration_value = migration_percentages.pop_back();
    let allocation_value = allocation_percentages.pop_back();
    let vesting_period = allocation_percentages.pop_back();

    creation_percentages.validate();
    swap_percentages.validate();
    migration_percentages.validate();
    allocation_percentages.validate();

    // @dev The other fees include dynamic recipients
    assert!(
        recipients[0].length() == creation_percentages.length(),
        memez_errors::invalid_creation_fee_config(),
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
        allocation: FeePayload {
            value: allocation_value,
            percentages: allocation_percentages,
            recipients: recipients[3],
        },
        vesting_period,
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
        Fee::Value(value, distributor) => {
            if (value == 0) return 0;

            assert!(asset.value() >= value, memez_errors::insufficient_value());

            let payment = asset.split(value, ctx);
            let payment_value = payment.value();

            distributor.send(payment, ctx);

            payment_value
        },
        Fee::Percentage(bps, distributor) => {
            if (bps.value() == 0) return 0;

            let asset_value = asset.value();
            let payment_value = bps.calc(asset_value);

            assert!(asset_value >= payment_value, memez_errors::insufficient_value());

            let payment = asset.split(payment_value, ctx);

            distributor.send(payment, ctx);

            payment_value
        },
    }
}

public(package) fun allocation_take<T>(
    allocation: &mut Allocation<T>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let value = allocation.balance.value();

    if (value == 0) return;

    let coin_to_send = allocation.balance.withdraw_all().into_coin(ctx);

    let vesting_period = allocation.vesting_period;

    allocation.distributor.send_vested(coin_to_send, clock, vesting_period, ctx);
}

public(package) fun creation(self: MemezFees): Fee {
    Fee::Value(
        self.creation.value,
        memez_distributor::new(self.creation.recipients, self.creation.percentages),
    )
}

public(package) fun swap(self: MemezFees, stake_holders: vector<address>): Fee {
    let mut recipients = self.swap.recipients;

    recipients.append(stake_holders);

    Fee::Percentage(
        bps::new(self.swap.value),
        memez_distributor::new(recipients, self.swap.percentages),
    )
}

public(package) fun migration(self: MemezFees, stake_holders: vector<address>): Fee {
    let mut recipients = self.migration.recipients;

    recipients.append(stake_holders);

    Fee::Value(
        self.migration.value,
        memez_distributor::new(recipients, self.migration.percentages),
    )
}

public(package) fun allocation<T>(
    self: MemezFees,
    balance: &mut Balance<T>,
    stake_holders: vector<address>,
): Allocation<T> {
    let mut recipients = self.allocation.recipients;

    recipients.append(stake_holders);

    let balance_value = balance.value();

    Allocation {
        balance: if (self.allocation.value == 0) balance::zero() else balance.split(bps::new(self.allocation.value).calc(balance_value)),
        vesting_period: self.vesting_period,
        distributor: memez_distributor::new(recipients, self.allocation.percentages),
    }
}

// === Internal Method Aliases ===

use fun memez_utils::validate_bps as vector.validate;

// === Public Method Aliases ===

public use fun allocation_take as Allocation.take;

// === Test Functions ===

#[test_only]
public fun new_value_fee(value: u64, distributor: Distributor): Fee {
    Fee::Value(value, distributor)
}

#[test_only]
public fun new_percentage_fee(value: u64, distributor: Distributor): Fee {
    Fee::Percentage(bps::new(value), distributor)
}

#[test_only]
public fun distributor(fee: Fee): Distributor {
    match (fee) {
        Fee::Percentage(_, distributor) => distributor,
        Fee::Value(_, distributor) => distributor,
    }
}

#[test_only]
public fun value(fee: Fee): u64 {
    match (fee) {
        Fee::Percentage(bps, _) => bps.value(),
        Fee::Value(value, _) => value,
    }
}

#[test_only]
public fun payloads(fees: MemezFees): vector<FeePayload> {
    vector[fees.creation, fees.swap, fees.migration, fees.allocation]
}

#[test_only]
public fun payload_value(payload: FeePayload): u64 {
    payload.value
}

#[test_only]
public fun payload_percentages(payload: FeePayload): vector<u64> {
    payload.percentages
}
#[test_only]
public fun payload_recipients(payload: FeePayload): vector<address> {
    payload.recipients
}

#[test_only]
public use fun allocation_value as Allocation.value;

#[test_only]
public fun allocation_value<T>(allocation: &Allocation<T>): u64 {
    allocation.balance.value()
}

#[test_only]
public use fun allocation_vesting_period as Allocation.vesting_period;
#[test_only]
public fun allocation_vesting_period<T>(allocation: &Allocation<T>): u64 {
    allocation.vesting_period
}

#[test_only]
public use fun allocation_distributor as Allocation.distributor;

#[test_only]
public fun allocation_distributor<T>(allocation: &Allocation<T>): Distributor {
    allocation.distributor
}
