module memez_pad::memez_pad;

use std::type_name::TypeName;

use sui::{
    sui::SUI,
    coin::Coin,
    balance::{Self, Balance}
};

use treasury_cap_v2::treasury_cap::{Self, MetadataCap};

use memez_fees::memez_fees::{MemezFees, Rate};

use memez_pad::migration::Migration;

// === Structs ===

public struct Allocation has store {
    amount: u64,
    vesting_period: Option<u64>, 
    vesting_start: Option<u64>,
    vesting_duration: Option<u64>,
}

public struct Lock {
    witness: TypeName,
}

public struct MemezSale<phantom Meme> has key {
    id: UID,
    start: u64,
    end: u64,
    meme: Balance<Meme>,
    sui: Balance<SUI>,  
    liquidity_amount: u64,
    burn_amount: u64,
    team_meme_allocation: Allocation,
    team_sui_allocation: Allocation, 
    minimum_raise: u64,
    target_raise: u64, 
    witness: TypeName,
    rate: Rate,
}

