module memez_fun::memez_config; 
// === Imports ===  

use sui::{
    sui::SUI,
    coin::Coin 
};

use memez_acl::acl::AuthWitness;

// === Constants ===  

// @dev 300,000,000 = 30%
const BURN_TAX: u64 = 300_000_000; 

const MAX_DEV_TOTAL_ALLOCATION: u64 = 150_000_000_000_000_000; 

const MIN_DEV_VESTING_DURATION: u64 = 3 * 86400 * 1_000; // 3 days in ms

const CREATION_FEE: u64 = 2_000_000_000; 

// === Errors === 

#[error]
const EDevAllocationExceedsMax: vector<u8> = b"Dev allocation exceeds max";

#[error]
const EDevVestingDurationTooShort: vector<u8> = b"Dev vesting duration is too short";

#[error]
const ENotEnoughSuiForCreationFee: vector<u8> = b"Not enough SUI for creation fee";

// === Structs ===  

public struct MemezConfig has key {
    id: UID, 
    auction_start_virtual_liquidity: u64, 
    auction_floor_virtual_liquidity: u64, 
    auction_target_sui_liquidity: u64,  
    bonding_target_sui_liquidity: u64, 
    sui_decay_amount: u64, 
    round_duration: u64, 
    burn_tax: u64, 
    creation_fee: u64, 
    max_dev_total_allocation: u64, 
    min_dev_vesting_duration: u64, 
    treasury: address
}

// === Initializer === 

fun init(ctx: &mut TxContext) {
    let config = MemezConfig {
        id: object::new(ctx),
        auction_start_virtual_liquidity: 0, 
        auction_floor_virtual_liquidity: 0, 
        auction_target_sui_liquidity: 0,  
        bonding_target_sui_liquidity: 0, 
        sui_decay_amount: 0, 
        round_duration: 0, 
        burn_tax: BURN_TAX, 
        creation_fee: CREATION_FEE, 
        max_dev_total_allocation: MAX_DEV_TOTAL_ALLOCATION, 
        min_dev_vesting_duration: MIN_DEV_VESTING_DURATION, 
        treasury: @treasury
    };

    transfer::share_object(config);
}

// === Public Admin Functions === 

public fun set_auction_start_virtual_liquidity(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    self.auction_start_virtual_liquidity = amount;
}

public fun set_auction_floor_virtual_liquidity(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    self.auction_floor_virtual_liquidity = amount;
} 

public fun set_auction_target_sui_liquidity(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    self.auction_target_sui_liquidity = amount;
}

public fun set_sui_decay_amount(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    self.sui_decay_amount = amount;
}

public fun set_round_duration(self: &mut MemezConfig, _: &AuthWitness, duration: u64) {
    self.round_duration = duration;
}

public fun set_burn_tax(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    self.burn_tax = amount;
}

public fun set_max_dev_total_allocation(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    self.max_dev_total_allocation = amount;
}

public fun set_min_dev_vesting_duration(self: &mut MemezConfig, _: &AuthWitness, duration: u64) {
    self.min_dev_vesting_duration = duration;
}

public fun set_creation_fee(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    self.creation_fee = amount;
}

// === Public Package Functions ===  

public(package) fun assert_dev_allocation_within_bounds(self: &MemezConfig, amount: u64) {
    assert!(amount <= self.max_dev_total_allocation, EDevAllocationExceedsMax);
}

public(package) fun assert_dev_vesting_duration_is_valid(self: &MemezConfig, duration: u64) {
    assert!(duration >= self.min_dev_vesting_duration, EDevVestingDurationTooShort);
}

public(package) fun take_creation_fee(self: &MemezConfig, creation_fee: Coin<SUI>) {
    assert!(creation_fee.value() >= self.creation_fee, ENotEnoughSuiForCreationFee);

    transfer::public_transfer(creation_fee, self.treasury);
}
 
public(package) fun get(self: &MemezConfig): (u64, u64, u64, u64, u64, u64, u64) {
    (
        self.auction_start_virtual_liquidity, 
        self.auction_floor_virtual_liquidity, 
        self.auction_target_sui_liquidity, 
        self.sui_decay_amount, 
        self.round_duration, 
        self.bonding_target_sui_liquidity, 
        self.burn_tax
    )
}