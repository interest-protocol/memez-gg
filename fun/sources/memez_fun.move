module memez_fun::memez_fun;
// === Imports === 

use sui::{
    sui::SUI,
    clock::Clock,
    balance::{Self, Balance},
    coin::{Coin, TreasuryCap, CoinMetadata},
};

use interest_math::u64;

use ipx_coin_standard::ipx_coin_standard::{Self, IPXTreasuryStandard, MetadataCap};

use memez_invariant::memez_invariant::get_amount_out;

use memez_fun::{
    version::CurrentVersion,
    memez_config::MemezConfig,
};

// === Constants ===

const POW_9: u64 = 1_000_000_000;

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
    dev_allocation: Balance<Meme>, 
    dev_vesting_duration: u64, 
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
    creation_fee: Coin<SUI>,
    dev_allocation: u64, 
    dev_vesting_duration: u64, 
    version: CurrentVersion,
    ctx: &mut TxContext
): MetadataCap {
    version.assert_is_valid();
    config.take_creation_fee(creation_fee);

    assert!(meme_metadata.get_decimals() == 9, EWrongDecimals); 
    assert!(meme_treasury_cap.total_supply() == 0, EPreMint); 

    config.assert_dev_allocation_within_bounds(dev_allocation);
    config.assert_dev_vesting_duration_is_valid(dev_vesting_duration);

    let (
        auction_start_virtual_liquidity, 
        auction_floor_virtual_liquidity, 
        auction_target_sui_liquidity, 
        sui_decay_amount, 
        round_duration, 
        bonding_target_sui_liquidity, 
        burn_tax
    ) = config.get();

    let mut meme_balance = meme_treasury_cap.mint(TOTAL_MEME_SUPPLY, ctx).into_balance(); 

    let dev_allocation = meme_balance.split(dev_allocation);

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
        dev_allocation, 
        dev_vesting_duration, 
        burn_tax, 
        sui_balance: balance::zero(), 
        meme_balance, 
        is_migrating: false,
    };

    let (mut ipx_treasury_standard, mut cap_witness) = ipx_coin_standard::new(meme_treasury_cap, ctx);

    cap_witness.add_burn_capability(&mut ipx_treasury_standard);

    transfer::share_object(memez_fun);
    transfer::public_share_object(ipx_treasury_standard);

    cap_witness.create_metadata_cap(ctx)
}

public fun bid<Meme>(
    self: &mut MemezFun<Meme>, 
    clock: &Clock, 
    bid: Coin<SUI>, 
    version: CurrentVersion, 
    ctx: &mut TxContext
): Bid<Meme> {
    version.assert_is_valid();

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

public fun fail_redeem<Meme>(
    self: &mut MemezFun<Meme>, 
    clock: &Clock, 
    bid: Bid<SUI>, 
    version: CurrentVersion, 
    ctx: &mut TxContext
): Coin<SUI> {
    version.assert_is_valid();

    let virtual_liquidity = self.auction_virtual_liquidity(clock);  

    assert!(self.bonding_start_virtual_liquidity == 0 && self.auction_floor_virtual_liquidity > virtual_liquidity, EAuctionDidNotFail); 

    let Bid { id, sui_amount, .. } = bid; 

    id.delete();

    self.sui_balance.split(sui_amount).into_coin(ctx)
}

public fun success_redeem<Meme>(
    self: &mut MemezFun<Meme>, 
    bid: Bid<Meme>, 
    version: CurrentVersion, 
    ctx: &mut TxContext
): Coin<Meme> {
    version.assert_is_valid();

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

public fun ape<Meme>(
    self: &mut MemezFun<Meme>, 
    sell: Coin<SUI>, 
    version: CurrentVersion, 
    ctx: &mut TxContext
): Coin<Meme> {
    version.assert_is_valid();
    self.assert_can_trade();

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

public fun jeet<Meme>(
    self: &mut MemezFun<Meme>, 
    treasury_cap: &mut IPXTreasuryStandard, 
    mut meme_coin: Coin<Meme>, 
    version: CurrentVersion, 
    ctx: &mut TxContext
): Coin<SUI> {
    version.assert_is_valid();
    self.assert_can_trade();

    let meme_balance_value = self.meme_balance.value();

    let sui_balance_value = self.sui_balance.value(); 

    let meme_coin_value = meme_coin.value();

    let real_meme_balance_value = meme_balance_value + self.total_redeemed_bid_amount - self.total_meme_bid_amount;

    let sui_virtual_liquidity = self.bonding_start_virtual_liquidity + sui_balance_value;

    let pre_tax_sui_value_out = get_amount_out(
        meme_coin_value, 
        real_meme_balance_value, 
        sui_virtual_liquidity
    ); 

    let dynamic_burn_tax = self.get_dynamic_burn_tax(sui_virtual_liquidity - pre_tax_sui_value_out);

    let meme_fee_value = u64::mul_div_up(meme_coin_value, dynamic_burn_tax, POW_9);

    treasury_cap.burn(meme_coin.split(meme_fee_value, ctx));

    let post_tax_sui_value_out = get_amount_out(
        meme_coin_value - meme_fee_value, 
        real_meme_balance_value, 
        sui_virtual_liquidity
    );

    self.meme_balance.join(meme_coin.into_balance()); 

    self.sui_balance.split(post_tax_sui_value_out).into_coin(ctx)
}

// === Public View Functions ===  

public fun meme_price<Meme>(self: &MemezFun<Meme>, clock: &Clock): u64 {
    if (self.bonding_start_virtual_liquidity == 0) {
        let virtual_liquidity = self.auction_virtual_liquidity(clock);  

        if (self.auction_floor_virtual_liquidity > virtual_liquidity) return 0; 

        return virtual_liquidity * POW_9 / TOTAL_MEME_SUPPLY
    }; 

    (self.bonding_start_virtual_liquidity + self.sui_balance.value()) * POW_9 / (self.meme_balance.value() + self.total_redeemed_bid_amount - self.total_meme_bid_amount)
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

fun get_dynamic_burn_tax<Meme>(
    self: &MemezFun<Meme>, 
    current_liquidity: u64
): u64 {
    if (current_liquidity >= self.bonding_target_sui_liquidity) return 0; 

    if (self.bonding_start_virtual_liquidity >= current_liquidity) return self.burn_tax; 

    let total_range = self.bonding_target_sui_liquidity - self.bonding_start_virtual_liquidity;  

    let progress = current_liquidity - self.bonding_start_virtual_liquidity;  

    let remaining_percentage = u64::mul_div_down(total_range - progress, POW_9, total_range);    

    u64::mul_div_up(self.burn_tax, remaining_percentage, POW_9)
}

fun assert_can_trade<Meme>(self: &MemezFun<Meme>) {
    assert!(self.bonding_start_virtual_liquidity != 0, EAuctionDidNotSucceed);
    assert!(!self.is_migrating, EIsMigrating);
}