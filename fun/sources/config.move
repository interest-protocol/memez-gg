module memez_fun::memez_config; 
// === Imports ===  

use memez_acl::acl::AuthWitness;

// === Constants ===  

// @dev 300,000,000 = 30%
const BURN_TAX: u64 = 300_000_000; 

// === Structs ===  

public struct MemezConfig has key {
    id: UID, 
    auction_start_virtual_liquidity: u64, 
    auction_floor_virtual_liquidity: u64, 
    auction_target_sui_liquidity: u64,  
    bonding_target_sui_liquidity: u64, 
    sui_decay_amount: u64, 
    round_duration: u64, 
    dev_allocation: u64, 
    burn_tax: u64
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
        dev_allocation: 0, 
        burn_tax: BURN_TAX
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

public fun set_dev_allocation(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    self.dev_allocation = amount;
}

public fun set_burn_tax(self: &mut MemezConfig, _: &AuthWitness, amount: u64) {
    self.burn_tax = amount;
}

// === Public Package Functions === 

public(package) fun get(self: &MemezConfig): (u64, u64, u64, u64, u64, u64, u64, u64) {
    (
        self.auction_start_virtual_liquidity, 
        self.auction_floor_virtual_liquidity, 
        self.auction_target_sui_liquidity, 
        self.sui_decay_amount, 
        self.round_duration, 
        self.dev_allocation,  
        self.bonding_target_sui_liquidity, 
        self.burn_tax
    )
}