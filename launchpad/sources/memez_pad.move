module memez_pad::memez_pad;

use std::type_name::{Self, TypeName};

use sui::{
    sui::SUI,
    clock::Clock,
    balance::{Self, Balance},
    coin::{Self, Coin, TreasuryCap},
};

use treasury_cap_v2::treasury_cap::{Self, MetadataCap, BurnCap};

use memez_acl::acl::AuthWitness;

use memez_fees::memez_fees::{MemezFees, Fee};

use memez_pad::migration::Migration;

// === Constants ===

// @dev 3% fee
const INITIAL_FEE: u64 = 30_000_000;

// === Errors ===

#[error]
const EInvalidSettings: vector<u8> = b"The settings vector must have 6 elements";

#[error]
const EInvalidStart: vector<u8> = b"The start time cannot be before the current timestamp";

#[error]
const EInvalidEnd: vector<u8> = b"The end time cannot be before the start time";

#[error]
const EInvalidMinimumRaise: vector<u8> = b"The minimum raise must be greater than 0";

#[error]
const EInvalidTargetRaise: vector<u8> = b"The target raise must be greater than the minimum raise";

#[error]
const EInvalidLiquidityAmount: vector<u8> = b"The liquidity amount must be greater than 0";

#[error]
const EInvalidAllocation: vector<u8> = b"The allocation vector must have 4 elements";

#[error]
const EInvalidTotalSupply: vector<u8> = b"The total supply does not match the sum of the allocations and the liquidity amount";

#[error]
const EInvalidTreasury: vector<u8> = b"The treasury must have no supply";

// === Structs ===

public struct FeeKey has copy, drop, store()

public struct Allocation has store {
    amount: u64,
    vesting_period: u64, 
    vesting_start: u64,
    vesting_duration: u64,
}

public struct Migrating {
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
    migrator_witness: TypeName,
    // @dev Cost of 1 Sui in meme
    fee: Fee,
}

// === Public Mutative Functions === 

public fun new<Meme, Witness: drop>(
    migration: &Migration,
    fees: &MemezFees,
    clock: &Clock,
    mut meme_treasury: TreasuryCap<Meme>,
    // @dev start, end, minimum_raise, target_raise, liquidity_amount, burn_amount 
    settings: vector<u64>,
    total_supply: u64,
    sui_allocation: vector<u64>,
    meme_allocation: vector<u64>,
    ctx: &mut TxContext,
): (BurnCap, MetadataCap) {
    assert!(settings.length() == 6, EInvalidSettings);
    assert!(meme_treasury.total_supply() == 0, EInvalidTreasury);

    let migrator_witness = type_name::get<Witness>();

    migration.assert_is_whitelisted(migrator_witness);

    let (
        start, 
        end, 
        minimum_raise, 
        target_raise, 
        liquidity_amount, 
        burn_amount
    ) = (settings[0], settings[1], settings[2], settings[3], settings[4], settings[5]);

    assert!(start > clock.timestamp_ms(), EInvalidStart);
    assert!(end > start, EInvalidEnd); 
    assert!(minimum_raise > 0, EInvalidMinimumRaise);
    assert!(target_raise > minimum_raise, EInvalidTargetRaise);
    assert!(liquidity_amount > 0, EInvalidLiquidityAmount);
    assert!(meme_allocation.length() == 4 && sui_allocation.length() == 4, EInvalidAllocation);

    let meme_allocation_amount = meme_allocation[0];
    let sui_allocation_amount = sui_allocation[0];

    assert!(
        total_supply > 0 && 
        total_supply == burn_amount + liquidity_amount + meme_allocation_amount + sui_allocation_amount, 
        EInvalidTotalSupply
    );  

    let meme = meme_treasury.mint(total_supply, ctx).into_balance();

    let (treasury_v2, mint_cap, burn_cap, metadata_cap) = treasury_cap::new(meme_treasury, ctx);

    mint_cap.destroy();

    transfer::public_share_object(treasury_v2);

    let sale = MemezSale {
        id: object::new(ctx),
        start,
        end,
        meme,
        sui: balance::zero(),
        liquidity_amount,
        burn_amount,
        team_meme_allocation: Allocation {
            amount: meme_allocation_amount,
            vesting_period: meme_allocation[1],
            vesting_start: meme_allocation[2],
            vesting_duration: meme_allocation[3],
        },
        team_sui_allocation: Allocation {
            amount: sui_allocation_amount,
            vesting_period: sui_allocation[1],
            vesting_start: sui_allocation[2],
            vesting_duration: sui_allocation[3],
        },
        minimum_raise,
        target_raise,
        migrator_witness,
        fee: fees.get(FeeKey()),
    };

    transfer::share_object(sale);

    (burn_cap, metadata_cap)
}

// === Admin Functions ===  

public fun set_fee(fees: &mut MemezFees, witness: &AuthWitness, rate: u64) {
    fees.add(witness, FeeKey(), rate);
}

