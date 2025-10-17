module memez_presale::memez_allocation;

use interest_bps::bps::{Self, BPS};
use memez_vesting::memez_vesting;
use sui::{balance::Balance, clock::Clock, coin::Coin};

// === Structs ===

public struct Recipient has copy, drop, store {
    address: address,
    bps: BPS,
    start_period: u64,
    vesting_duration: u64,
}

public struct Allocation<phantom T> has store {
    total: u64,
    balance: Balance<T>,
    recipients: vector<Recipient>,
}

// === Public Functions ===

public fun new_recipient(
    address: address,
    bps_value: u64,
    start_period: u64,
    vesting_duration: u64,
): Recipient {
    Recipient { address, bps: bps::new(bps_value), start_period, vesting_duration }
}

// === Package Functions ===

public(package) fun new_allocation<T>(balance: Balance<T>): Allocation<T> {
    Allocation {
        total: balance.value(),
        balance,
        recipients: vector[],
    }
}

public(package) fun add_recipient<T>(self: &mut Allocation<T>, recipient: Recipient) {
    self.recipients.push_back(recipient);
}

public(package) fun send<T>(allocation: &mut Allocation<T>, clock: &Clock, ctx: &mut TxContext) {
    let value = allocation.balance.value();

    if (value == 0) return;

    let mut coin_to_send = allocation.balance.withdraw_all().into_coin(ctx);

    allocation
        .recipients
        .do_ref!(
            |recipient| if (recipient.start_period <= clock.timestamp_ms()) {
                let recipient_coin = coin_to_send.split(recipient.bps.calc(value), ctx);

                if (recipient.vesting_duration == 0) {
                    transfer::public_transfer(recipient_coin, recipient.address);
                } else { let vesting = memez_vesting::new(clock, recipient_coin, recipient.start_period, recipient.vesting_duration, ctx);  transfer::public_transfer(vesting, recipient.address); };
            },
        );

    coin_to_send.destroy_or_burn!();
}

public(package) fun validate_recipients(recipients: vector<Recipient>) {
    recipients.map!(|recipient| recipient.bps.value()).validate_bps!();
}

// === Aliases ===

use fun memez_presale::memez_utils::validate_bps as vector.validate_bps;
use fun memez_presale::memez_utils::coin_destroy_or_burn as Coin.destroy_or_burn;
