module memez_otc::otc;
// === Imports === 

use sui::{
    sui::SUI,
    coin::Coin,
    clock::Clock,
    balance::Balance,
};

use interest_math::u64;

use memez_otc::{
    events,
    fees::{Fees, Rate},
    account::MemezOTCAccount,
    vesting_wallet::{Self, Wallet},
};

// === Errors === 

#[error]
const ENotOwner: vector<u8> = b"You are not the owner of this OTC";

#[error] 
const EZeroOTCPrice: vector<u8> = b"You cannot start an OTC with 0 price";

#[error]
const ENoOTCDeal: vector<u8> = b"You must provide a coin to OTC";

#[error]
const ENotEnoughBalance: vector<u8> = b"The OTC does not have enough balance to sell";

#[error]
const EInvalidBuyAmount: vector<u8> = b"The amount bought is too low";

#[error] 
const EVestedOTC: vector<u8> = b"This is a vested OTC, use buy_vested instead";

#[error]
const ENotVestedOTC: vector<u8> = b"This is not a vested OTC, use buy instead";

// === Structs === 

public struct MemezOTC<phantom CoinType> has key {
    id: UID,
    balance: Balance<CoinType>,
    owner: address, 
    recipient: address,
    deposited_amount: u64,
    price: u64,
    rate: Rate,
    vesting_duration: Option<u64>
}

// === Public Mutative Functions ===  

public fun new<CoinType>(
    fees: &Fees,
    account: &mut MemezOTCAccount, 
    coin_in:Coin<CoinType>, 
    recipient: address,
    price: u64, 
    vesting_duration: Option<u64>,
    ctx: &mut TxContext
) {
    assert!(price > 0, EZeroOTCPrice);
    assert!(coin_in.value() > 0, ENoOTCDeal);

    let coin_in_value = coin_in.value();

    let memez_otc = MemezOTC {      
        id: object::new(ctx),
        balance: coin_in.into_balance(),
        owner: account.addy(),
        recipient,
        deposited_amount: coin_in_value,
        price,
        rate: fees.rate(),
        vesting_duration
   };

   events::new_otc<CoinType>(
        memez_otc.id.to_address(), 
        account.addy(), 
        recipient, 
        coin_in_value, 
        price, 
        fees.value(),
        vesting_duration
    );

   transfer::share_object(memez_otc);
}

public fun buy<CoinType>(self: &mut MemezOTC<CoinType>, coin_in: Coin<SUI>, ctx: &mut TxContext): Coin<CoinType> {
    assert!(self.vesting_duration.is_none(), EVestedOTC);

    buy_internal(self, coin_in, ctx).into_coin(ctx)
}

public fun buy_vested<CoinType>(self: &mut MemezOTC<CoinType>, clock: &Clock, coin_in: Coin<SUI>, ctx: &mut TxContext): Wallet<CoinType> {
    assert!(self.vesting_duration.is_some(), ENotVestedOTC);

    let balance_out = buy_internal(self, coin_in, ctx);

    vesting_wallet::new(
        balance_out, 
        clock, 
        self.vesting_duration.destroy_some(), 
        ctx
    )
}

public fun destroy<CoinType>(self: MemezOTC<CoinType>, account: &MemezOTCAccount, ctx: &mut TxContext): Coin<CoinType> {
    assert!(account.addy() == self.owner, ENotOwner);

    let MemezOTC { id, balance, .. } = self;

    id.delete();

    balance.into_coin(ctx)
}

// === Public View Functions === 

public fun calculate_amount_in<CoinType>(self: &MemezOTC<CoinType>, amount_out: u64): u64 {
    self.rate.calculate_amount_in(u64::mul_div_up(amount_out, self.price, self.deposited_amount))
}

public fun calculate_amount_out<CoinType>(self: &MemezOTC<CoinType>, amount_in: u64): u64 {
    let amount = calculate_amount_out_internal(amount_in, self.price, self.deposited_amount);

    amount - self.rate.calculate_fee(amount)
}

// === Private Functions === 

fun calculate_amount_out_internal(
    amount_in: u64,
    price: u64,
    deposited_amount: u64,
): u64 {
    u64::mul_div_down(amount_in, deposited_amount, price)
}

fun buy_internal<CoinType>(self: &mut MemezOTC<CoinType>, mut coin_in: Coin<SUI>, ctx: &mut TxContext): Balance<CoinType> {
    let amount_out = calculate_amount_out_internal(coin_in.value(), self.price, self.deposited_amount);

    assert!(amount_out != 0, EInvalidBuyAmount);
    assert!(self.balance.value() >= amount_out, ENotEnoughBalance);

    let coin_in_value = coin_in.value();

    transfer::public_transfer(
        coin_in.split(self.rate.calculate_fee(coin_in_value), ctx), 
        self.recipient
    );

    transfer::public_transfer(coin_in, self.recipient);

    let fee_value = self.rate.calculate_fee(amount_out);

    transfer::public_transfer(self.balance.split(fee_value).into_coin(ctx), self.owner);

    let balance_out = self.balance.split(amount_out - fee_value);

    events::otc_buy<CoinType>(self.id.to_address(), coin_in_value, balance_out.value(), self.vesting_duration);

    balance_out
}