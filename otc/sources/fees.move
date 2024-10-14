module memez_otc::fees;
// === Imports === 

use interest_math::u64;

use memez_acl::acl::AuthWitness;

// === Constants ===  

// @dev 10^9
const PRECISION: u64 = 1__000_000_000;

// @dev 1%
const INITIAL_RATE: u64 = 10_000_000; 

// @dev 10%
const MAX_RATE: u64 = 100_000_000; 

// === Errors === 

#[error]
const EFeeIsTooHigh: vector<u8> = b"The fee is too high";

// === Structs ===  

public struct Rate has store, copy, drop {
    value: u64,
}

public struct Fees has key {
    id: UID,
    treasury: address, 
    rate: Rate,
}

// === Initializers ===  

fun init(ctx: &mut TxContext) {
    let fees = Fees {
        id: object::new(ctx),
        treasury: @treasury,
        rate: Rate {
            value: INITIAL_RATE,
        },
    };

    transfer::share_object(fees);
}

// === Public Package View Functions ===  

public(package) fun treasury(fees: &Fees): address {
    fees.treasury
}

public(package) fun calculate_fee(rate: Rate, amount: u64): u64 {
    u64::mul_div_up(amount, rate.value, PRECISION)
}

public(package) fun calculate_amount_in(rate: Rate, amount: u64): u64 {
    u64::mul_div_up(amount, PRECISION, PRECISION - rate.value)
}

public(package) fun rate(fees: &Fees): Rate {
    fees.rate
}

public(package) fun value(self: &Fees): u64 {
    self.rate.value
}

// === Admin Functions ===  

public fun set_fee(fees: &mut Fees, _: &AuthWitness, fee:u64) {
    assert!(MAX_RATE >= fee, EFeeIsTooHigh);

    fees.rate.value = fee;
}

public fun set_treasury(fees: &mut Fees, _: &AuthWitness, treasury: address) {
    fees.treasury = treasury;
}

// === Tests ===  

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}

#[test_only]
public(package) fun rate_value(rate: &Rate): u64 {
    rate.value
}