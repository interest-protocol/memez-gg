module memez_vesting::memez_soulbound_vesting;

use sui::{balance::Balance, clock::Clock, coin::Coin};

// === Structs ===

public struct MemezSoulBoundVesting<phantom T> has key {
    id: UID,
    balance: Balance<T>,
    start: u64,
    released: u64,
    duration: u64,
}

// === Public Mutative Functions ===

public fun new<T>(
    clock: &Clock,
    coin: Coin<T>,
    start: u64,
    duration: u64,
    ctx: &mut TxContext,
): MemezSoulBoundVesting<T> {
    assert!(start >= clock.timestamp_ms(), memez_vesting::memez_vesting_errors::invalid_start!());
    assert!(duration != 0, memez_vesting::memez_vesting_errors::zero_duration!());
    assert!(coin.value() != 0, memez_vesting::memez_vesting_errors::zero_allocation!());

    MemezSoulBoundVesting {
        id: object::new(ctx),
        balance: coin.into_balance(),
        released: 0,
        start,
        duration,
    }
}

public fun claim<T>(
    self: &mut MemezSoulBoundVesting<T>,
    clock: &Clock,
    ctx: &mut TxContext,
): Coin<T> {
    let releasable = vesting_status(self, clock);

    *&mut self.released = self.released + releasable;

    self.balance.split(releasable).into_coin(ctx)
}

public fun destroy_zero<T>(self: MemezSoulBoundVesting<T>) {
    let MemezSoulBoundVesting { id, balance, .. } = self;

    id.delete();

    balance.destroy_zero()
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

// === Tests ===

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
