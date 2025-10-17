module memez_presale::memez_allocation;

use interest_bps::bps::{Self, BPS};
use sui::balance::Balance;

// === Structs ===

public struct Recipient has copy, drop, store {
    address: address,
    bps: BPS,
}

public struct Distributor has copy, drop, store {
    recipients: vector<Recipient>,
}

public struct Allocation<phantom T> has store {
    balance: Balance<T>,
    vesting_periods: vector<u64>,
    distributor: Distributor,
}
