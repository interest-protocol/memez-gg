module memez_otc::vesting_wallet;
// === Imports === 

use sui::{
    coin::Coin,
    clock::Clock,
    balance::Balance,
};

public struct Wallet<phantom T> has key, store {
    id: UID,
    balance: Balance<T>,
    start: u64,
    released: u64,
    duration: u64
}

// === Public Mutative Functions ===

public fun claim<T>(self: &mut Wallet<T>, c: &Clock, ctx: &mut TxContext): Coin<T> {
    let releasable = vesting_status(self, c);

    *&mut self.released = self.released + releasable;

    self.balance.split(releasable).into_coin(ctx)
}

public fun destroy_zero<T>(self: Wallet<T>) {
    let Wallet { id, balance, .. } = self;
    
    id.delete();

    balance.destroy_zero()
}

// === Public View Function ===

public fun vesting_status<T>(self: &Wallet<T>, clock: &Clock): u64 {
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
): Wallet<T> {
    Wallet {
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
