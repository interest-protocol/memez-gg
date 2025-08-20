module memez::memez;

use interest_access_control::access_control;
use sui::package;

public struct MEMEZ() has drop;

const DELAY: u64 = 7;

fun init(otw: MEMEZ, ctx: &mut TxContext) {
    transfer::public_share_object(access_control::new(&otw, DELAY, ctx.sender(), ctx));
    package::claim_and_keep(otw, ctx);
}

// === Test Functions ===

#[test_only]
public fun init_for_test(ctx: &mut TxContext) {
    init(MEMEZ(), ctx);
}
