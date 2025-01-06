module memez_otc::memez_otc;

use interest_bps::bps::{Self, BPS};
use interest_math::u64;
use memez_acl::acl::AuthWitness;
use memez_otc::{config::MemezOTCConfig, errors, events};
use memez_vesting::memez_vesting::{Self, MemezVesting};
use sui::{balance::Balance, clock::Clock, coin::{Coin, CoinMetadata}, sui::SUI};

// === Imports ===

// === Structs ===

public struct MemezOTC<phantom CoinType> has key {
    id: UID,
    balance: Balance<CoinType>,
    owner: address,
    recipient: address,
    deposited_meme_amount: u64,
    desired_sui_amount: u64,
    fee: BPS,
    meme_scalar: u64,
    vesting_duration: Option<u64>,
    deadline: Option<u64>,
}

// === Public Mutative Functions ===

public fun new<Meme>(
    coin_metadata: &CoinMetadata<Meme>,
    config: &MemezOTCConfig,
    meme_coin: Coin<Meme>,
    desired_sui_amount: u64,
    recipient: address,
    vesting_duration: Option<u64>,
    deadline: Option<u64>,
    ctx: &mut TxContext,
): MemezOTC<Meme> {
    assert!(desired_sui_amount != 0, errors::zero_price());

    let meme_coin_value = meme_coin.value();

    let meme_scalar = u64::pow(10, coin_metadata.get_decimals() as u64);

    let fee = config.fee();

    let memez_otc = MemezOTC {
        id: object::new(ctx),
        balance: meme_coin.into_balance(),
        owner: ctx.sender(),
        recipient: recipient,
        deposited_meme_amount: meme_coin_value,
        desired_sui_amount: desired_sui_amount,
        fee,
        vesting_duration: vesting_duration,
        deadline: deadline,
        meme_scalar,
    };

    events::new<Meme>(
        memez_otc.id.to_address(),
        memez_otc.owner,
        memez_otc.recipient,
        meme_coin_value,
        desired_sui_amount,
        fee.value(),
        meme_scalar,
        vesting_duration,
        deadline,
    );

    memez_otc
}
