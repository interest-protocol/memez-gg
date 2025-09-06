module memez_vesting::memez_soulbound_vesting;

use sui::{balance::Balance, clock::Clock, coin::Coin};

// === Structs ===

public struct MemezSoulBoundVesting<phantom T> has key {
    id: UID,
    balance: Balance<T>,
    start: u64,
    released: u64,
    duration: u64,
    owner: address,
}

// === Public Mutative Functions ===

public fun new<T>(
    clock: &Clock,
    coin: Coin<T>,
    start: u64,
    duration: u64,
    owner: address,
    ctx: &mut TxContext,
): MemezSoulBoundVesting<T> {
    let coin_value = coin.value();

    assert!(
        start >= clock.timestamp_ms() - memez_vesting::memez_vesting_constants::delay_margin_ms!(),
        memez_vesting::memez_vesting_errors::invalid_start!(),
    );
    assert!(duration != 0, memez_vesting::memez_vesting_errors::zero_duration!());
    assert!(coin_value != 0, memez_vesting::memez_vesting_errors::zero_allocation!());

    let memez_soulbound_vesting = MemezSoulBoundVesting {
        id: object::new(ctx),
        balance: coin.into_balance(),
        released: 0,
        start,
        duration,
        owner,
    };

    memez_vesting::memez_vesting_events::new<T>(
        memez_soulbound_vesting.id.to_address(),
        owner,
        coin_value,
        start,
        duration,
    );

    memez_soulbound_vesting
}

public fun transfer_to_owner<T>(self: MemezSoulBoundVesting<T>) {
    let owner = self.owner;
    transfer::transfer(self, owner);
}

public fun claim<T>(
    self: &mut MemezSoulBoundVesting<T>,
    clock: &Clock,
    ctx: &mut TxContext,
): Coin<T> {
    let releasable = vesting_status(self, clock);

    *&mut self.released = self.released + releasable;

    let coin = self.balance.split(releasable).into_coin(ctx);

    memez_vesting::memez_vesting_events::claimed<T>(
        self.id.to_address(),
        releasable,
    );

    coin
}

public fun destroy_zero<T>(self: MemezSoulBoundVesting<T>) {
    let MemezSoulBoundVesting { id, balance, .. } = self;

    memez_vesting::memez_vesting_events::destroyed<T>(id.to_address());

    id.delete();

    balance.destroy_zero();
}

// === Public View Function ===

public fun vesting_status<T>(self: &MemezSoulBoundVesting<T>, clock: &Clock): u64 {
    let vested = memez_vesting::memez_vesting_core::linear_vesting_amount!(
        self.start,
        self.duration,
        self.balance.value() + self.released,
        clock.timestamp_ms(),
    );

    vested - self.released
}

// === Test Functions ===

#[test_only]
public fun id<T>(self: &MemezSoulBoundVesting<T>): address {
    self.id.to_address()
}

#[test_only]
public fun balance<T>(self: &MemezSoulBoundVesting<T>): u64 {
    self.balance.value()
}

#[test_only]
public fun start<T>(self: &MemezSoulBoundVesting<T>): u64 {
    self.start
}

#[test_only]
public fun released<T>(self: &MemezSoulBoundVesting<T>): u64 {
    self.released
}

#[test_only]
public fun duration<T>(self: &MemezSoulBoundVesting<T>): u64 {
    self.duration
}
