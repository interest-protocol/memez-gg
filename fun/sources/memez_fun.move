module memez_fun::memez_fun;
// === Imports === 

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

use interest_math::u64;

use ipx_coin_standard::ipx_coin_standard::{Self, IPXTreasuryStandard, MetadataCap};

use memez_invariant::memez_invariant::get_amount_out;

use memez_acl::acl::AuthWitness;

use memez_fun::{
    migration::Migration,
    memez_config::MemezConfig
};

// === Constants ===

const SUI_DECIMALS_SCALAR: u64 = 1_000_000_000;

const TOTAL_MEME_SUPPLY: u64 = 1_000_000_000_000_000_000;

// === Errors === 

#[error]
const EWrongDecimals: vector<u8> = b"Meme coins must have 9 decimals"; 

#[error]
const EPreMint: vector<u8> = b"Meme treasury cap must have no supply"; 

#[error]
const EZeroBid: vector<u8> = b"Bid must be greater than 0"; 

#[error]
const EAuctionFailed: vector<u8> = b"Auction failed"; 

#[error]
const EAuctionEnded: vector<u8> = b"Auction ended"; 

#[error]
const EAuctionDidNotFail: vector<u8> = b"Auction did not fail"; 

#[error]
const EAuctionDidNotSucceed: vector<u8> = b"Auction did not succeed"; 

#[error]
const EIsMigrating: vector<u8> = b"Memez is migrating"; 

// === Structs ===

public struct MigrationFeeKey has copy, drop, store() 

public struct CreationFeeKey has copy, drop, store() 

public struct MemezFun<phantom Meme> has key {
    id: UID,
    start_time: u64, 
    auction_start_virtual_liquidity: u64, 
    auction_floor_virtual_liquidity: u64, 
    auction_target_sui_liquidity: u64,  
    bonding_start_virtual_liquidity: u64,
    bonding_target_sui_liquidity: u64,
    total_sui_bid_amount: u64,
    total_meme_bid_amount: u64,
    total_redeemed_bid_amount: u64,
    sui_balance: Balance<SUI>,
    meme_balance: Balance<Meme>, 
    sui_decay_amount: u64, 
    round_duration: u64, 
    dev_allocation: u64, 
    burn_tax: u64, 
    is_migrating: bool,
}

public struct Bid<phantom Meme> has key {
    id: UID,
    sui_amount: u64,
    virtual_liquidity: u64
}

// === Public Mutative Functions === 

#[allow(lint(share_owned))]
public fun new<Meme>(
    config: &MemezConfig,
    clock: &Clock, 
    meme_metadata: &CoinMetadata<Meme>,
    mut meme_treasury_cap: TreasuryCap<Meme>,
    ctx: &mut TxContext
): MetadataCap {
    assert!(meme_metadata.get_decimals() == 9, EWrongDecimals); 
    assert!(meme_treasury_cap.total_supply() == 0, EPreMint); 

    let (
        auction_start_virtual_liquidity, 
        auction_floor_virtual_liquidity, 
        auction_target_sui_liquidity, 
        sui_decay_amount, 
        round_duration, 
        dev_allocation, 
        bonding_target_sui_liquidity, 
        burn_tax
    ) = config.get();

    let memez_fun = MemezFun<Meme> {
        id: object::new(ctx),
        start_time: clock.timestamp_ms(),
        auction_start_virtual_liquidity, 
        auction_floor_virtual_liquidity, 
        auction_target_sui_liquidity, 
        bonding_start_virtual_liquidity: 0,
        bonding_target_sui_liquidity, 
        total_sui_bid_amount: 0,
        total_meme_bid_amount: 0,
        total_redeemed_bid_amount: 0,
        sui_decay_amount, 
        round_duration, 
        burn_tax, 
        sui_balance: balance::zero(), 
        meme_balance: meme_treasury_cap.mint(TOTAL_MEME_SUPPLY, ctx).into_balance(), 
        dev_allocation, 
        is_migrating: false,
    };

    let (mut ipx_treasury_standard, mut cap_witness) = ipx_coin_standard::new(meme_treasury_cap, ctx);

    cap_witness.add_burn_capability(&mut ipx_treasury_standard);

    transfer::share_object(memez_fun);
    transfer::public_share_object(ipx_treasury_standard);

    cap_witness.create_metadata_cap(ctx)
}

public fun bid<Meme>(self: &mut MemezFun<Meme>, clock: &Clock, bid: Coin<SUI>, ctx: &mut TxContext): Bid<Meme> {
    assert!(self.bonding_start_virtual_liquidity == 0, EAuctionEnded);

    let bid_value = bid.value();  

    assert!(bid_value != 0, EZeroBid); 

    let virtual_liquidity = self.auction_virtual_liquidity(clock);  

    assert!(virtual_liquidity >= self.auction_floor_virtual_liquidity, EAuctionFailed);

    let total_sui_balance = self.sui_balance.join(bid.into_balance()); 

    self.total_sui_bid_amount = self.total_sui_bid_amount + bid_value; 

    if (total_sui_balance >= self.auction_target_sui_liquidity) {
        self.bonding_start_virtual_liquidity = virtual_liquidity;
        self.total_meme_bid_amount = get_amount_out(
            self.total_sui_bid_amount, 
            virtual_liquidity, 
            TOTAL_MEME_SUPPLY
        );
    };

    Bid {
        id: object::new(ctx),
        sui_amount: bid_value,
        virtual_liquidity
    }   
}

public fun fail_redeem<Meme>(self: &mut MemezFun<Meme>, clock: &Clock, bid: Bid<SUI>, ctx: &mut TxContext): Coin<SUI> {
    let virtual_liquidity = self.auction_virtual_liquidity(clock);  

    assert!(self.bonding_start_virtual_liquidity == 0 && self.auction_floor_virtual_liquidity > virtual_liquidity, EAuctionDidNotFail); 

    let Bid { id, sui_amount, .. } = bid; 

    id.delete();

    self.sui_balance.split(sui_amount).into_coin(ctx)
}

public fun success_redeem<Meme>(self: &mut MemezFun<Meme>, bid: Bid<Meme>, ctx: &mut TxContext): Coin<Meme> {
    assert!(self.bonding_start_virtual_liquidity != 0, EAuctionDidNotSucceed);  

    let Bid { id, sui_amount, .. } = bid; 

    let meme_amount = get_amount_out(
        sui_amount, 
        self.bonding_start_virtual_liquidity, 
        TOTAL_MEME_SUPPLY
    );

    self.total_redeemed_bid_amount = self.total_redeemed_bid_amount + meme_amount; 

    id.delete();

    self.meme_balance.split(meme_amount).into_coin(ctx)
}

public fun ape<Meme>(self: &mut MemezFun<Meme>, sell: Coin<SUI>, ctx: &mut TxContext): Coin<Meme> {
    assert!(self.bonding_start_virtual_liquidity != 0, EAuctionDidNotSucceed);
    assert!(!self.is_migrating, EIsMigrating);

    let sui_amount = sell.value(); 

    let total_sui_balance = self.sui_balance.join(sell.into_balance()); 

    let meme_balance_value = self.meme_balance.value();  

    if (total_sui_balance >= self.bonding_target_sui_liquidity)
        self.is_migrating = true;

    self.meme_balance.split(
        get_amount_out(
            sui_amount, 
            self.bonding_start_virtual_liquidity + total_sui_balance, 
            meme_balance_value + self.total_redeemed_bid_amount - self.total_meme_bid_amount
        )
    ).into_coin(ctx)
}

public fun jeet<Meme>(self: &mut MemezFun<Meme>, treasury_cap: &mut IPXTreasuryStandard, sell: Coin<Meme>, ctx: &mut TxContext): Coin<SUI> {
    assert!(self.bonding_start_virtual_liquidity != 0, EAuctionDidNotSucceed);
    assert!(!self.is_migrating, EIsMigrating);

    let meme_amount = sell.value(); 

    let total_meme_balance = self.meme_balance.join(sell.into_balance()); 

    let total_sui_balance = self.sui_balance.value(); 

    self.sui_balance.split(
        get_amount_out(
            meme_amount, 
            total_meme_balance + self.total_redeemed_bid_amount - self.total_meme_bid_amount, 
            self.bonding_start_virtual_liquidity + total_sui_balance
        )
    ).into_coin(ctx)
}

// === Public View Functions ===  

public fun meme_price<Meme>(self: &MemezFun<Meme>, clock: &Clock): u64 {
    if (self.bonding_start_virtual_liquidity == 0) {
        let virtual_liquidity = self.auction_virtual_liquidity(clock);  

        if (self.auction_floor_virtual_liquidity > virtual_liquidity) return 0; 

        return virtual_liquidity * SUI_DECIMALS_SCALAR / TOTAL_MEME_SUPPLY
    }; 

    (self.bonding_start_virtual_liquidity + self.sui_balance.value()) * SUI_DECIMALS_SCALAR / (self.meme_balance.value() + self.total_redeemed_bid_amount - self.total_meme_bid_amount)
}

public fun auction_virtual_liquidity<Meme>(self: &MemezFun<Meme>, clock: &Clock): u64 {
    if (self.bonding_start_virtual_liquidity != 0) return 0;

    let round = (clock.timestamp_ms() - self.start_time) / self.round_duration; 

    if (round == 0) return self.auction_start_virtual_liquidity;  

    self.auction_start_virtual_liquidity - u64::min(self.sui_decay_amount * round, self.auction_start_virtual_liquidity)
}

public fun bonding_virtual_liquidity<Meme>(self: &MemezFun<Meme>): u64 {
    if (self.bonding_start_virtual_liquidity == 0) return 0;  

    self.bonding_start_virtual_liquidity + self.sui_balance.value()
}

// === Private Functions === 


