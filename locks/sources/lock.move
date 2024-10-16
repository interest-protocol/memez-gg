module memez_locks::lock;
// === Imports === 

use sui::dynamic_object_field as dof;

use memez_acl::acl::AuthWitness;

use memez_fees::memez_fees::{Rate, MemezFees};

// === Errors === 

#[error] 
const EInvalidEpoch: vector<u8> = b"The epoch cannot be in the past.";

#[error]
const EPositionLocked: vector<u8> = b"The position is still locked.";

// === Structs === 

public struct FeeKey has copy, store, drop()

public struct PositionKey has store, copy, drop()

public struct MemezLock has key, store {
    id: UID,
    rate: Rate,
    treasury: address,
    unlock_epoch: u64,
    amount_a: u64,
    amount_b: u64, 
    total_fees_a: u64,
    total_fees_b: u64, 
    total_admin_fees_a: u64,
    total_admin_fees_b: u64,
}

// === Admin Functions ===  

public fun set_fee(fees: &mut MemezFees, witness: &AuthWitness, rate: u64) {
    fees.add(witness, FeeKey(), rate);
}

// === Public Package Functions ===  

public(package) fun new<T: key + store>( 
    fees: &MemezFees,
    position: T, 
    unlock_epoch: u64,
    ctx: &mut TxContext
): MemezLock {
    assert!(unlock_epoch > ctx.epoch(), EInvalidEpoch);

    let mut memez_lock = MemezLock {
        id: object::new(ctx),
        treasury: fees.treasury(),
        rate: fees.rate(FeeKey()),
        unlock_epoch,
        amount_a: 0,
        amount_b: 0, 
        total_fees_a: 0,
        total_fees_b: 0, 
        total_admin_fees_a: 0,
        total_admin_fees_b: 0,
    };

    dof::add(&mut memez_lock.id, PositionKey(), position);

    memez_lock
}

public(package) fun destroy<T: key + store>(self: MemezLock, ctx: &TxContext): T {
    assert!(ctx.epoch() > self.unlock_epoch, EPositionLocked);

    let MemezLock {
        mut id,
        unlock_epoch: _,
        ..
    } = self;
    
    let position = dof::remove(&mut id, PositionKey());

    id.delete();

    position
}

public(package) fun add_amounts(self: &mut MemezLock, amount_a: u64, amount_b: u64) {
    self.amount_a = self.amount_a + amount_a;
    self.amount_b = self.amount_b + amount_b;
}

public(package) fun add_fees(self: &mut MemezLock, fees_a: u64, fees_b: u64) {
    self.total_fees_a = self.total_fees_a + fees_a;
    self.total_fees_b = self.total_fees_b + fees_b;
}

public(package) fun add_admin_fees(self: &mut MemezLock, fees_a: u64, fees_b: u64) {
    self.total_admin_fees_a = self.total_admin_fees_a + fees_a;
    self.total_admin_fees_b = self.total_admin_fees_b + fees_b;
}

public(package) fun borrow<T: key + store>(self: &MemezLock): &T {
    dof::borrow(&self.id, PositionKey())
}

public(package) fun borrow_mut<T: key + store>(self: &mut MemezLock): &mut T {
    dof::borrow_mut(&mut self.id, PositionKey())
}

public(package) fun treasury(self: &MemezLock): address {
    self.treasury
}

public(package) fun rate(self: &MemezLock): Rate {
    self.rate
}

// === Test Only Functions ===  

#[test_only]
public fun amounts(self: &MemezLock): (u64, u64) {
    (self.amount_a, self.amount_b)
}

#[test_only]
public fun total_fees(self: &MemezLock): (u64, u64) {
    (self.total_fees_a, self.total_fees_b)
}

#[test_only]
public fun total_admin_fees(self: &MemezLock): (u64, u64) {
    (self.total_admin_fees_a, self.total_admin_fees_b)
}

#[test_only]
public fun unlock_epoch(self: &MemezLock): u64 {
    self.unlock_epoch
}