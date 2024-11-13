module memez_fun::memez_fun;

use std::{
    u64::pow,
    type_name::{Self, TypeName}
};

use sui::{
    sui::SUI,
    clock::Clock,
    table::{Self, Table},
    balance::{Self, Balance},
    coin::{Self, Coin, TreasuryCap, CoinMetadata},
};

use ipx_coin_standard::ipx_coin_standard::{Self, MetadataCap};

use memez_acl::acl::AuthWitness;

use memez_fees::memez_fees::{MemezFees, Fee};

use memez_fun::migration::Migration;

// === Constants ===

const SUI_DECIMALS_SCALAR: u64 = 1_000_000_000;

// === Errors ===

// === Structs ===

public struct FeeKey has copy, drop, store()

public struct MemezSale<phantom Meme> has key {
    id: UID,
}

// === Public Mutative Functions === 

// === Admin Functions ===  

public fun set_fee(fees: &mut MemezFees, witness: &AuthWitness, rate: u64) {
    fees.add(witness, FeeKey(), rate);
}