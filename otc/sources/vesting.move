module memez_otc::vesting_wallet;
// === Imports === 

use sui::{
    coin::Coin,
    clock::Clock,
    balance::Balance,
};

public struct VestingWallet<phantom T> has key, store {
    id: UID,
    balance: Balance<T>,
    start: u64,
    released: u64,
    duration: u64
}

// === Public Mutative Functions ===

public fun claim<T>(self: &mut VestingWallet<T>, clock: &Clock, ctx: &mut TxContext): Coin<T> {
    let releasable = vesting_status(self, clock);

    *&mut self.released = self.released + releasable;

    self.balance.split(releasable).into_coin(ctx)
}

public fun destroy_zero<T>(self: VestingWallet<T>) {
    let VestingWallet { id, balance, .. } = self;
    
    id.delete();

    balance.destroy_zero()
}

// === Public View Function ===

public fun vesting_status<T>(self: &VestingWallet<T>, clock: &Clock): u64 {
    let vested = linear_vesting_amount(
        self.start,
        self.duration,
        self.balance.value() + self.released,
        clock.timestamp_ms(),
    );

    vested - self.released
}

// === Public Package Functions ===

public(package) fun new<T>(
    balance: Balance<T>,
    clock: &Clock,
    duration: u64,
    ctx: &mut TxContext,
): VestingWallet<T> {
    VestingWallet {
        id: object::new(ctx),
        balance,
        released: 0,
        start: clock.timestamp_ms(),
        duration,
    }
}

// === Private Functions ===

fun linear_vesting_amount(
    start: u64,
    duration: u64,
    total_allocation: u64,
    timestamp: u64,
): u64 {
    if (timestamp < start) return 0;
    if (timestamp > start + duration) return total_allocation;
    (total_allocation * (timestamp - start)) / duration
}

// === Tests === 

#[test_only]
public fun balance<T>(self: &VestingWallet<T>): u64 {
    self.balance.value()
} 

#[test_only]
public fun start<T>(self: &VestingWallet<T>): u64 {
    self.start
}

#[test_only]
public fun released<T>(self: &VestingWallet<T>): u64 {
    self.released
}

#[test_only]
public fun duration<T>(self: &VestingWallet<T>): u64 {
    self.duration
}