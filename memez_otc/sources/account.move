module memez_otc::account;
// === Imports === 

use sui::vec_set::{Self, VecSet};

// === Structs === 

public struct MemezOTCAccount has key, store {
    id: UID,
    otcs: VecSet<address>,
}

// === Public Mutative Functions === 

public fun new(ctx: &mut TxContext): MemezOTCAccount {
     MemezOTCAccount {
        id: object::new(ctx),
        otcs: vec_set::empty(),
    }
}

// === Public Package Functions === 

public(package) fun addy(self: &MemezOTCAccount): address {
    self.id.to_address()
}

public(package) fun add_otc(self: &mut MemezOTCAccount, otc: address) {
    self.otcs.insert(otc);
}

public(package) fun remove_otc(self: &mut MemezOTCAccount, otc: address) {
    self.otcs.remove(&otc);
}