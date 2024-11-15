module memez_locks::turbos_lock;
// === Imports === 

use std::u64;

use sui::{
    coin::Coin,
    clock::Clock,
};

use turbos_clmm::{
    pool::{Pool, Versioned},
    position_nft::TurbosPositionNFT,
    position_manager::{Self, Positions},
}; 

use memez_locks::lock::{Self, MemezLock};

// === Public Mutative Functions ===  

public fun lock(
    positions: &Positions,
    position: TurbosPositionNFT, 
    unlock_epoch: u64,
    ctx: &mut TxContext
): MemezLock {
    let (amount_a, amount_b, _) = positions.get_position_info(position.position_id().to_address());
    
    let mut memez_lock = lock::new(
        position, 
        unlock_epoch, 
        ctx
    );

    memez_lock.add_amounts((amount_a.as_u32() as u64), (amount_b.as_u32() as u64)); 

    memez_lock
}

public fun unlock(
    lock: MemezLock,  
    ctx: &TxContext
): TurbosPositionNFT {
    lock.destroy(ctx)
}

public fun collect<CoinTypeA, CoinTypeB, FeeType>(
    lock: &mut MemezLock,
    pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>, 
    positions: &mut Positions,
    versioned: &Versioned, 
    clock: &Clock,
    ctx: &mut TxContext
): (Coin<CoinTypeA>, Coin<CoinTypeB>) {

    let max_u64 = u64::max_value!();

    let (coin_a, coin_b) = position_manager::collect_with_return_(
        pool, 
        positions, 
        lock.borrow_mut(), 
        max_u64, 
        max_u64, 
        ctx.sender(), 
        max_u64, 
        clock, 
        versioned, 
        ctx
    );

    (coin_a, coin_b)
}
