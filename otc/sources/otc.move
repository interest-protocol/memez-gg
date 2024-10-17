module memez_otc::memez_otc;
// === Imports === 

use sui::{
    sui::SUI,
    coin::Coin,
    clock::Clock,
    balance::Balance,
};

use interest_math::u64;

use memez_acl::acl::AuthWitness;

use memez_fees::memez_fees::{MemezFees, Rate};

use memez_vesting::vesting_wallet::{Self, VestingWallet};

use memez_otc::events;

// === Errors === 

#[error]
const EWrongOwner: vector<u8> = b"You are not the owner of this OTC";

#[error] 
const EZeroPrice: vector<u8> = b"You cannot start an OTC without a price";

#[error]
const EZeroCoin: vector<u8> = b"You must provide a coin to OTC";

#[error]
const ENotEnoughBalance: vector<u8> = b"The OTC does not have enough balance to sell";

#[error]
const EInvalidBuyAmount: vector<u8> = b"The amount bought is too low";

#[error] 
const EVestedOTC: vector<u8> = b"This is a vested OTC, use buy_vested instead";

#[error]
const ENormalOTC: vector<u8> = b"This is not a vested OTC, use buy instead";

#[error]
const EDeadlinePassed: vector<u8> = b"The deadline has passed";

#[error]
const EHasNoDeadline: vector<u8> = b"This OTC has no deadline";

#[error]
const EHasDeadline: vector<u8> = b"This OTC has a deadline";

// === Structs === 

public struct FeeKey has copy, store, drop()

public struct MemezOTCAccount has key, store {
    id: UID,
}

public struct MemezOTC<phantom CoinType> has key {
    id: UID,
    balance: Balance<CoinType>,
    owner: address, 
    recipient: address,
    deposited_amount: u64,
    price: u64,
    rate: Rate,
    vesting_duration: Option<u64>,
    deadline: Option<u64>
}

// === Public Mutative Functions ===  

public fun new_account(ctx: &mut TxContext): MemezOTCAccount {
     MemezOTCAccount {
        id: object::new(ctx),
    }
}

public fun new<CoinType>(
    account: &mut MemezOTCAccount, 
    fees: &MemezFees,
    coin_in:Coin<CoinType>, 
    recipient: address,
    price: u64, 
    vesting_duration: Option<u64>,
    deadline: Option<u64>,
    ctx: &mut TxContext
) {
    assert!(price > 0, EZeroPrice);

    let coin_in_value = coin_in.value();

    assert!(coin_in_value > 0, EZeroCoin);

    let memez_otc = MemezOTC {      
        id: object::new(ctx),
        balance: coin_in.into_balance(),
        owner: account.id.to_address(),
        recipient,
        deposited_amount: coin_in_value,
        price,
        rate: fees.rate(FeeKey()),
        vesting_duration,
        deadline
   };

   events::new<CoinType>(
        memez_otc.id.to_address(), 
        account.id.to_address(), 
        recipient, 
        coin_in_value, 
        price, 
        fees.value(FeeKey()),
        vesting_duration
    );

   transfer::share_object(memez_otc);
}

public fun buy<CoinType>(self: &mut MemezOTC<CoinType>, coin_in: Coin<SUI>, ctx: &mut TxContext): Coin<CoinType> {
    assert!(self.vesting_duration.is_none(), EVestedOTC);
    assert!(self.deadline.is_none(), EHasDeadline);

    buy_internal(self, coin_in, ctx).into_coin(ctx)
}

public fun buy_with_deadline<CoinType>(
    self: &mut MemezOTC<CoinType>,
    clock: &Clock,
    coin_in: Coin<SUI>,
    ctx: &mut TxContext
): Coin<CoinType> {
    assert!(self.deadline.is_some(), EHasNoDeadline);
    assert!(*self.deadline.borrow() >= clock.timestamp_ms(), EDeadlinePassed);

    buy_internal(self, coin_in, ctx).into_coin(ctx)
}

public fun buy_vested<CoinType>(
    self: &mut MemezOTC<CoinType>, 
    clock: &Clock, 
    coin_in: Coin<SUI>, 
    ctx: &mut TxContext
): VestingWallet<CoinType> {
    assert!(self.vesting_duration.is_some(), ENormalOTC);
    assert!(self.deadline.is_none(), EHasDeadline);

    let balance_out = buy_internal(self, coin_in, ctx);

    vesting_wallet::new(
        balance_out.into_coin(ctx), 
        clock, 
        self.vesting_duration.destroy_some(), 
        ctx
    )
}

public fun buy_vested_with_deadline<CoinType>(
    self: &mut MemezOTC<CoinType>,
    clock: &Clock,
    coin_in: Coin<SUI>,
    ctx: &mut TxContext
): VestingWallet<CoinType> {
    assert!(self.deadline.is_some(), EHasNoDeadline);
    assert!(*self.deadline.borrow() >= clock.timestamp_ms(), EDeadlinePassed);

    let balance_out = buy_internal(self, coin_in, ctx);

    vesting_wallet::new(
        balance_out.into_coin(ctx), 
        clock, 
        self.vesting_duration.destroy_some(), 
        ctx
    )
}

public fun update_deadline<CoinType>(self: &mut MemezOTC<CoinType>, account: &MemezOTCAccount, deadline: u64) {
    assert!(self.deadline.is_some(), EHasNoDeadline); 

    assert!(account.id.to_address() == self.owner, EWrongOwner);

    *self.deadline.borrow_mut() = deadline;
}

public fun destroy<CoinType>(self: MemezOTC<CoinType>, account: &MemezOTCAccount, ctx: &mut TxContext): Coin<CoinType> {
    assert!(account.id.to_address() == self.owner, EWrongOwner);

    let MemezOTC { id, balance, .. } = self;

    id.delete();

    balance.into_coin(ctx)
}

public fun destroy_account(self: MemezOTCAccount) {
    let MemezOTCAccount { id } = self; 

    id.delete();
}

// === Public View Functions === 

public fun calculate_amount_in<CoinType>(self: &MemezOTC<CoinType>, amount_out: u64): u64 {
    self.rate.calculate_amount_in(u64::mul_div_up(amount_out, self.price, self.deposited_amount))
}

public fun calculate_amount_out<CoinType>(self: &MemezOTC<CoinType>, amount_in: u64): u64 {
    let amount = calculate_amount_out_internal(amount_in, self.price, self.deposited_amount);

    amount - self.rate.calculate_fee(amount)
}

// === Admin Functions ===  

public fun set_fee(fees: &mut MemezFees, witness: &AuthWitness, rate: u64) {
    fees.add(witness, FeeKey(), rate);
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
    let coin_in_value = coin_in.value();

    let amount_out = calculate_amount_out_internal(coin_in_value, self.price, self.deposited_amount);

    assert!(amount_out != 0, EInvalidBuyAmount);
    assert!(self.balance.value() >= amount_out, ENotEnoughBalance);

    let fee_in = self.rate.calculate_fee(coin_in_value);

    transfer::public_transfer(
        coin_in.split(fee_in, ctx), 
        self.recipient
    );

    transfer::public_transfer(coin_in, self.recipient);

    let fee_out = self.rate.calculate_fee(amount_out);

    transfer::public_transfer(self.balance.split(fee_out).into_coin(ctx), self.owner);

    let balance_out = self.balance.split(amount_out - fee_out);

    events::buy<CoinType>(
        self.id.to_address(), 
        coin_in_value, 
        amount_out, 
        fee_in, 
        fee_out,
        self.vesting_duration
    );

    balance_out
}

#[test_only]
public fun addy(account: &MemezOTCAccount): address {
    account.id.to_address()
}

#[test_only] 
public fun balance<T>(otc: &MemezOTC<T>): u64 {
    otc.balance.value()
}

#[test_only]
public fun owner<T>(otc: &MemezOTC<T>): address {
    otc.owner
}

#[test_only]
public fun recipient<T>(otc: &MemezOTC<T>): address {
    otc.recipient
}

#[test_only]
public fun deposited_amount<T>(otc: &MemezOTC<T>): u64 {
    otc.deposited_amount
}

#[test_only]
public fun price<T>(otc: &MemezOTC<T>): u64 {
    otc.price
}

#[test_only]
public fun fee_rate<T>(otc: &MemezOTC<T>): u64 {
    otc.rate.rate_value()
}

#[test_only]
public fun vesting_duration<T>(otc: &MemezOTC<T>): Option<u64> {
    otc.vesting_duration
}

#[test_only]
public fun deadline<T>(otc: &MemezOTC<T>): Option<u64> {
    otc.deadline
}   