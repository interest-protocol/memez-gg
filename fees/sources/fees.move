module memez_fees::memez_fees;
// === Imports === 

use sui::{
    event::emit,
    dynamic_field as df
};

use interest_math::u64;

use memez_acl::acl::AuthWitness;

// === Constants ===  

// @dev 10^9
const PRECISION: u64 = 1__000_000_000;

// @dev 10%
const MAX_RATE: u64 = 100_000_000; 

// === Errors === 

#[error]
const EFeeIsTooHigh: vector<u8> = b"The fee is too high";

// === Structs ===  

public struct Fee has store, copy, drop {
    value: u64,
}

public struct MemezFees has key {
    id: UID,
    treasury: address, 
}

// === Events ===  

public struct FeeSet<Key: copy + store + drop> has copy, drop(Key, u64)

public struct RemoveFee<Key: copy + store + drop> has copy, drop(Key)

// === Initializers ===  

fun init(ctx: &mut TxContext) {
    let self = MemezFees {
        id: object::new(ctx),
        treasury: @treasury,
    };

    transfer::share_object(self);
}

// === Public View Functions ===  

public fun precision(): u64 {
    PRECISION
}   

public fun treasury(self: &MemezFees): address {
    self.treasury
}

public fun get<Key: copy + store + drop>(self: &MemezFees, key: Key): Fee {
    *df::borrow<Key, Fee>(&self.id, key)
}

public fun value<Key: copy + store + drop>(self: &MemezFees, key: Key): u64 {
    self.get(key).value
}

public fun has<Key: copy + store + drop>(self: &MemezFees, key: Key): bool {
    df::exists_with_type<Key, Fee>(&self.id, key)
}

public fun calculate_fee(fee: Fee, amount: u64): u64 {
    u64::mul_div_up(amount, fee.value, PRECISION)
}

public fun calculate_amount_in(fee: Fee, amount: u64): u64 {
    u64::mul_div_up(amount, PRECISION, PRECISION - fee.value)
}

// === Admin Functions ===  

public fun add<Key: copy + store + drop>(self: &mut MemezFees, _: &AuthWitness, key: Key, value: u64) {
    assert!(MAX_RATE >= value, EFeeIsTooHigh);

    if (df::exists_with_type<Key, Fee>(&self.id, key)) {
        let fee = df::borrow_mut<Key, Fee>(&mut self.id, key);
        fee.value = value;
    } else {
        df::add(&mut self.id, key, Fee { value });
    };

    emit(FeeSet (key, value));
}

public fun remove<Key: copy + store + drop>(self: &mut MemezFees, _: &AuthWitness, key: Key): Fee {
    emit(RemoveFee(key));
    
    df::remove<Key, Fee>(&mut self.id, key)
}

public fun set_treasury(self: &mut MemezFees, _: &AuthWitness, treasury: address) {
    self.treasury = treasury;
}

// === Tests ===  

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}

#[test_only]
public fun fee_value(fee: &Fee): u64 {
    fee.value
}