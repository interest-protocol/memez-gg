module recrd::recrd;

use memez_acl::acl::AuthWitness;
use cetus_clmm::pool_creator::create_pool_v2;

// === Structs === 

public struct RecrdConfig has key {
    id: UID,
    tick_spacing: u32,
    initialize_price: u128,
    tick_lower_idx: u32,
    tick_upper_idx: u32,
}

// === Initializer ===

fun init(ctx: &mut TxContext) {
    let recrd = RecrdConfig {
        id: object::new(ctx),
        tick_spacing: 0,
        initialize_price: 0,
        tick_lower_idx: 0,
        tick_upper_idx: 0,
    };

    transfer::share_object(recrd);
}

// === Admin Functions ===

public fun set_tick_spacing(self: &mut RecrdConfig, _: &AuthWitness, tick_spacing: u32) {
    self.tick_spacing = tick_spacing;
}

public fun set_initialize_price(self: &mut RecrdConfig, _: &AuthWitness, initialize_price: u128) {
    self.initialize_price = initialize_price;
}

public fun set_tick_range(self: &mut RecrdConfig, _: &AuthWitness, tick_lower_idx: u32, tick_upper_idx: u32) {
    self.tick_lower_idx = tick_lower_idx;
    self.tick_upper_idx = tick_upper_idx;
}
