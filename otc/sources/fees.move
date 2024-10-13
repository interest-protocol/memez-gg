module memez_otc::fees;
// === Imports === 

use interest_math::u64;

use memez_otc::acl::AuthWitness;

// === Constants ===  

// @dev 10^9
const PRECISION: u64 = 1__000_000_000;

// @dev 1%
const INITIAL_RATE: u64 = 10_000_000; 

// @dev 10%
const MAX_RATE: u64 = 100_000_000; 

// === Errors === 

#[error]
const ERateIsTooHigh: vector<u8> = b"The rate is too high";

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

public fun set_rate(fees: &mut Fees, _: AuthWitness, rate: Rate) {
    assert!(MAX_RATE >= rate.value, ERateIsTooHigh);

    fees.rate = rate;
}

public fun set_treasury(fees: &mut Fees, _: AuthWitness, treasury: address) {
    fees.treasury = treasury;
}