module memez_locks::cetus_lock;
// === Imports === 

use sui::coin::Coin;

use cetus_clmm::{
    pool::{Self, Pool},
    position::Position,
    config::GlobalConfig
};

use memez_locks::lock::{Self, MemezLock};

// === Public Mutative Functions ===  

public fun lock<CoinTypeA, CoinTypeB>(
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    position: Position, 
    unlock_epoch: u64,
    ctx: &mut TxContext
): MemezLock {
    let (amount_a, amount_b) = pool.get_position_amounts(object::id(&position));

    let mut memez_lock = lock::new(
        position, 
        unlock_epoch, 
        ctx
    );

    memez_lock.add_amounts(amount_a, amount_b);

    memez_lock
}

public fun unlock(
    lock: MemezLock,  
    ctx: &TxContext
): Position {
    lock.destroy(ctx)
}

public fun collect<CoinTypeA, CoinTypeB>(
    lock: &mut MemezLock,
    config: &GlobalConfig,
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    ctx: &mut TxContext
): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
    let (balance_a, balance_b) = pool::collect_fee(
        config,
        pool,
        lock.borrow(),
        true
    );

    (balance_a.into_coin(ctx), balance_b.into_coin(ctx))
}

// === Public Views === 

public fun pending_fees<CoinTypeA, CoinTypeB>(
    pool: &Pool<CoinTypeA, CoinTypeB>,
    position: address
): (u64, u64) {
    pool.get_position_fee(object::id_from_address(position))
}