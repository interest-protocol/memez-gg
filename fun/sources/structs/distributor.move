// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

#[allow(lint(self_transfer))]
module memez_fun::memez_distributor;

use interest_bps::bps::{Self, BPS};
use memez_vesting::memez_vesting;
use sui::{clock::Clock, coin::Coin};

// === Structs ===

public struct Recipient has copy, drop, store {
    address: address,
    bps: BPS,
}

public struct Distributor has copy, drop, store {
    recipients: vector<Recipient>,
}

// === Public Package Functions ===

public(package) fun new(recipients: vector<address>, percentages: vector<u64>): Distributor {
    Distributor {
        recipients: recipients.zip_map!(
            percentages,
            |address, bps| Recipient { address, bps: bps::new(bps) },
        ),
    }
}

public(package) fun send<T>(self: &Distributor, coin_to_send: Coin<T>, ctx: &mut TxContext) {
    self.distribute_internal!(
        |coin, recipient, _, _| transfer::public_transfer(coin, recipient),
        coin_to_send,
        ctx,
    )
}

public(package) fun maybe_send_vested<T>(
    self: &Distributor,
    coin_to_send: Coin<T>,
    clock: &Clock,
    vesting_periods: vector<u64>,
    ctx: &mut TxContext,
) {
    self.distribute_internal!(|coin, recipient, idx, ctx| if (vesting_periods[idx] == 0) {
        transfer::public_transfer(coin, recipient)
    } else {
        transfer::public_transfer(
            memez_vesting::new(
                clock,
                coin,
                clock.timestamp_ms(),
                vesting_periods[idx],
                ctx,
            ),
            recipient,
        )
    }, coin_to_send, ctx)
}

// === Private Functions ===

macro fun distribute_internal<$T>(
    $self: &Distributor,
    $f: |Coin<$T>, address, u64, &mut TxContext|,
    $coin_to_send: Coin<$T>,
    $ctx: &mut TxContext,
) {
    let mut coin_to_send = $coin_to_send;
    let ctx = $ctx;
    let self = $self;

    let payment_value = coin_to_send.value();

    let mut idx = 0;

    self.recipients.do_ref!(|beneficiary| {
        let current_value = coin_to_send.value();
        let value_to_transfer = beneficiary.bps.calc_up(payment_value).min(current_value);

        if (value_to_transfer == 0) {
            idx = idx + 1;
            return
        };

        $f(coin_to_send.split(value_to_transfer, ctx), beneficiary.address, idx, ctx);
        idx = idx + 1;
    });

    coin_to_send.destroy_or_burn!();
}
// === Method Aliases ===

use fun memez_fun::memez_utils::coin_destroy_or_burn as Coin.destroy_or_burn;

// === Test Functions ===

#[test_only]
public fun recipient_addresses(self: &Distributor): vector<address> {
    self.recipients.map!(|recipient| recipient.address)
}

#[test_only]
public fun recipient_percentages(self: &Distributor): vector<BPS> {
    self.recipients.map!(|recipient| recipient.bps)
}
