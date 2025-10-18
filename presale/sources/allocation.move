module memez_presale::memez_allocation;

use interest_bps::bps::{Self, BPS};
use memez_vesting::memez_soulbound_vesting;
use sui::{balance::Balance, clock::Clock, coin::Coin};

// === Structs ===

public struct Recipient has copy, drop, store {
    address: address,
    bps: BPS,
    start_duration: u64,
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
    start_duration: u64,
    vesting_duration: u64,
): Recipient {
    Recipient { address, bps: bps::new(bps_value), start_duration, vesting_duration }
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
    if (allocation.total == 0) return;

    let mut coin_to_send = allocation.balance.withdraw_all().into_coin(ctx);

    allocation.recipients.do_ref!(|recipient| {
        let recipient_coin = coin_to_send.split(recipient.bps.calc(allocation.total), ctx);

        if (recipient.vesting_duration == 0) {
            transfer::public_transfer(recipient_coin, recipient.address);
        } else {
            memez_soulbound_vesting::new(
                clock,
                recipient_coin,
                clock.timestamp_ms() + recipient.start_duration,
                recipient.vesting_duration,
                recipient.address,
                ctx,
            ).transfer_to_owner();
        };
    });

    coin_to_send.destroy_or_burn!();
}

public(package) fun validate_recipients(recipients: vector<Recipient>) {
    recipients.map!(|recipient| recipient.bps.value()).validate_bps!();
}

// === Aliases ===

use fun memez_presale::memez_utils::validate_bps as vector.validate_bps;
use fun memez_presale::memez_utils::coin_destroy_or_burn as Coin.destroy_or_burn;
