module memez_otc::config;

use interest_bps::bps::{Self, BPS};
use memez_acl::acl::AuthWitness;

// === Constants ===

const ONE_PERCENT: u64 = 100;

// === Structs ===

public struct MemezOTCConfig has key {
    id: UID,
    fee: BPS,
    treasury: address,
}

// === Initializer ===

fun init(ctx: &mut TxContext) {
    let config = MemezOTCConfig {
        id: object::new(ctx),
        fee: bps::new(ONE_PERCENT),
        treasury: @treasury,
    };

    transfer::share_object(config);
}

// === Admin Functions ===

public fun set_fee(self: &mut MemezOTCConfig, _: &AuthWitness, fee: u64) {
    self.fee = bps::new(fee);
}

public fun set_treasury(self: &mut MemezOTCConfig, _: &AuthWitness, treasury: address) {
    self.treasury = treasury;
}

// === Public Read Functions ===

public fun fee(self: &MemezOTCConfig): BPS {
    self.fee
}

public fun treasury(self: &MemezOTCConfig): address {
    self.treasury
}

// === Test Only Functions ===

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}
