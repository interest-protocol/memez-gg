module memez_fun::memez_distributor;

use interest_bps::bps::{Self, BPS};
use memez_fun::memez_utils;
use memez_vesting::memez_vesting;
use sui::{clock::Clock, coin::Coin};

// === Structs ===

public struct Recipient has copy, drop, store {
    addy: address,
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
            |addy, bps| Recipient { addy, bps: bps::new(bps) },
        ),
    }
}

public(package) fun send<T>(self: &Distributor, coin_to_send: Coin<T>, ctx: &mut TxContext) {
    self.distribute_internal!(
        |coin, recipient, _| transfer::public_transfer(coin, recipient),
        coin_to_send,
        ctx,
    )
}

public(package) fun send_vested<T>(
    self: &Distributor,
    coin_to_send: Coin<T>,
    clock: &Clock,
    vesting_period: u64,
    ctx: &mut TxContext,
) {
    self.distribute_internal!(
        |coin, recipient, ctx| transfer::public_transfer(
            memez_vesting::new(
                clock,
                coin,
                clock.timestamp_ms(),
                vesting_period,
                ctx,
            ),
            recipient,
        ),
        coin_to_send,
        ctx,
    )
}

// === Private Functions ===

macro fun distribute_internal<$T>(
    $self: &Distributor,
    $f: |Coin<$T>, address, &mut TxContext|,
    $coin_to_send: Coin<$T>,
    $ctx: &mut TxContext,
) {
    let mut coin_to_send = $coin_to_send;
    let ctx = $ctx;
    let self = $self;

    let payment_value = coin_to_send.value();

    self.recipients.do_ref!(|beneficiary| {
        let current_value = coin_to_send.value();
        let value_to_transfer = beneficiary.bps.calc(payment_value).min(current_value);

        if (value_to_transfer == 0) return;

        $f(coin_to_send.split(value_to_transfer, ctx), beneficiary.addy, ctx);
    });

    coin_to_send.destroy_or_return(ctx);
}
// === Method Aliases ===

use fun memez_utils::destroy_or_return as Coin.destroy_or_return;

// === Test Functions ===
