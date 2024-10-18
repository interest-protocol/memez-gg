module memez_locks::cetus_lock;
// === Imports === 

use sui::coin::Coin;

use cetus_clmm::{
    pool::{Self, Pool},
    position::Position,
    config::GlobalConfig
};

use memez_fees::memez_fees::MemezFees;

use memez_locks::lock::{Self, MemezLock};

// === Public Mutative Functions ===  

public fun lock<CoinTypeA, CoinTypeB>(
    fees: &MemezFees,
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    position: Position, 
    unlock_epoch: u64,
    ctx: &mut TxContext
): MemezLock {
    let (amount_a, amount_b) = pool.get_position_amounts(object::id(&position));

    let mut memez_lock = lock::new(
        fees,
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

    let mut coin_a = balance_a.into_coin(ctx);
    let mut coin_b = balance_b.into_coin(ctx);
    
    let coin_a_value = coin_a.value();
    let coin_b_value = coin_b.value();

    let fee = lock.fee();
    
    let coin_admin_a = coin_a.split(fee.calculate_fee(coin_a_value), ctx);
    let coin_admin_b = coin_b.split(fee.calculate_fee(coin_b_value), ctx);

    let coin_a_admin_value = coin_admin_a.value();
    let coin_b_admin_value = coin_admin_b.value();

    let treasury = lock.treasury();

    transfer::public_transfer(coin_admin_a, treasury);
    transfer::public_transfer(coin_admin_b, treasury);

    lock.add_fees(coin_a_value - coin_a_admin_value, coin_b_value - coin_b_admin_value);
    lock.add_admin_fees(coin_a_admin_value, coin_b_admin_value);

    (coin_a, coin_b)
}

// === Public Views === 

public fun pending_fees<CoinTypeA, CoinTypeB>(
    pool: &Pool<CoinTypeA, CoinTypeB>,
    position: address
): (u64, u64) {
    pool.get_position_fee(object::id_from_address(position))
}