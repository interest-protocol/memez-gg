module memez_otc::memez_otc;
// === Imports === 

use sui::{
    sui::SUI,
    coin::{Coin, CoinMetadata},
    clock::Clock,
    balance::Balance,
};

use interest_math::u64;

use interest_bps::bps::{Self, BPS};

use memez_acl::acl::AuthWitness;

use memez_vesting::memez_vesting::{Self, MemezVesting};

use memez_otc::events;

use memez_otc::errors;

// === Structs === 

public struct MemezOTC<phantom CoinType> has key {
    id: UID,
    balance: Balance<CoinType>,
    owner: address, 
    recipient: address,
    deposited_amount: u64,
    desired_sui_amount: u64,
    fee: BPS,
    vesting_duration: Option<u64>,
    deadline: Option<u64>
}

// === Public Mutative Functions ===  

public fun new<CoinType>() {}