module memez_vesting::memez_vesting;

use sui::{balance::Balance, clock::Clock, coin::Coin};

// === Errors ===

#[error]
const EZeroAllocation: vector<u8> = b"You cannot create a vesting contract with zero allocation";

#[error]
const EZeroDuration: vector<u8> = b"You cannot create a vesting contract with zero duration";

#[error]
const EZeroStart: vector<u8> = b"You cannot create a vesting contract in the past";

// === Structs ===

public struct MemezVesting<phantom T> has key, store {
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
): MemezVesting<T> {
    assert!(
        start >= clock.timestamp_ms() - memez_vesting::memez_vesting_constants::delay_margin_ms!(),
        EZeroStart,
    );
    assert!(duration != 0, EZeroDuration);
    assert!(coin.value() != 0, EZeroAllocation);

    MemezVesting {
        id: object::new(ctx),
        balance: coin.into_balance(),
        released: 0,
        start,
        duration,
    }
}

public fun claim<T>(self: &mut MemezVesting<T>, clock: &Clock, ctx: &mut TxContext): Coin<T> {
    let releasable = vesting_status(self, clock);

    *&mut self.released = self.released + releasable;

    self.balance.split(releasable).into_coin(ctx)
}

public fun destroy_zero<T>(self: MemezVesting<T>) {
    let MemezVesting { id, balance, .. } = self;

    id.delete();

    balance.destroy_zero()
}

// === Public View Function ===

public fun vesting_status<T>(self: &MemezVesting<T>, clock: &Clock): u64 {
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
public fun balance<T>(self: &MemezVesting<T>): u64 {
    self.balance.value()
}

#[test_only]
public fun start<T>(self: &MemezVesting<T>): u64 {
    self.start
}

#[test_only]
public fun released<T>(self: &MemezVesting<T>): u64 {
    self.released
}

#[test_only]
public fun duration<T>(self: &MemezVesting<T>): u64 {
    self.duration
}
