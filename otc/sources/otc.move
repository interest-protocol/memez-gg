#[allow(unused_function)]
module memez_otc::memez_otc;

use interest_bps::bps::{BPS, max_bps};
use interest_math::u64;
use memez_otc::{config::MemezOTCConfig, errors, events};
use memez_vesting::memez_vesting::{Self, MemezVesting};
use sui::{balance::Balance, clock::Clock, coin::{Self, Coin}, sui::SUI};

// === Constants ===

const SUI_SCALAR: u64 = 1__000_000_000;

// === Structs ===

public struct MemezOTC<phantom Meme> has key {
    id: UID,
    balance: Balance<Meme>,
    owner: address,
    recipient: address,
    deposited_meme_amount: u64,
    desired_sui_amount: u64,
    fee: BPS,
    vesting_duration: Option<u64>,
    deadline: Option<u64>,
    treasury: address,
}

// === Public Mutative Functions ===

public fun new<Meme>(
    config: &MemezOTCConfig,
    clock: &Clock,
    meme_coin: Coin<Meme>,
    desired_sui_amount: u64,
    recipient: address,
    vesting_duration: Option<u64>,
    deadline: Option<u64>,
    ctx: &mut TxContext,
): MemezOTC<Meme> {
    assert!(desired_sui_amount != 0, errors::zero_price());
    assert!(recipient != @0x0, errors::invalid_recipient());
    assert!(
        deadline.is_none() || *deadline.borrow_with_default(&0) > clock.timestamp_ms(),
        errors::deadline_in_past(),
    );

    let meme_coin_value = meme_coin.value();

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
        treasury: config.treasury(),
    };

    events::new<Meme>(
        memez_otc.id.to_address(),
        memez_otc.owner,
        memez_otc.recipient,
        meme_coin_value,
        desired_sui_amount,
        fee.value(),
        vesting_duration,
        deadline,
    );

    memez_otc
}

public fun share<Meme>(self: MemezOTC<Meme>) {
    transfer::share_object(self);
}

public fun buy<Meme>(
    self: &mut MemezOTC<Meme>,
    sui_coin: Coin<SUI>,
    ctx: &mut TxContext,
): (Coin<SUI>, Coin<Meme>) {
    assert!(self.vesting_duration.is_none(), errors::vested_otc());
    assert!(self.deadline.is_none(), errors::has_deadline());

    self.buy_internal(sui_coin, ctx)
}

public fun buy_with_deadline<Meme>(
    self: &mut MemezOTC<Meme>,
    clock: &Clock,
    sui_coin: Coin<SUI>,
    ctx: &mut TxContext,
): (Coin<SUI>, Coin<Meme>) {
    assert!(self.deadline.is_some(), errors::has_no_deadline());
    assert!(self.vesting_duration.is_none(), errors::vested_otc());
    assert!(*self.deadline.borrow() >= clock.timestamp_ms(), errors::deadline_passed());

    self.buy_internal(sui_coin, ctx)
}

public fun buy_with_vesting<Meme>(
    self: &mut MemezOTC<Meme>,
    clock: &Clock,
    sui_coin: Coin<SUI>,
    ctx: &mut TxContext,
): (Coin<SUI>, MemezVesting<Meme>) {
    assert!(self.deadline.is_none(), errors::has_deadline());
    assert!(self.vesting_duration.is_some(), errors::normal_otc());

    let (sui_coin, meme_coin) = self.buy_internal(sui_coin, ctx);

    let now = clock.timestamp_ms();

    let memez_vesting = memez_vesting::new(
        clock,
        meme_coin,
        now,
        self.vesting_duration.destroy_some(),
        ctx,
    );

    (sui_coin, memez_vesting)
}

public fun buy_with_vesting_and_deadline<Meme>(
    self: &mut MemezOTC<Meme>,
    clock: &Clock,
    sui_coin: Coin<SUI>,
    ctx: &mut TxContext,
): (Coin<SUI>, MemezVesting<Meme>) {
    assert!(self.deadline.is_some(), errors::has_no_deadline());
    assert!(self.vesting_duration.is_some(), errors::normal_otc());
    assert!(*self.deadline.borrow() >= clock.timestamp_ms(), errors::deadline_passed());

    let (sui_coin, meme_coin) = self.buy_internal(sui_coin, ctx);

    let now = clock.timestamp_ms();

    let memez_vesting = memez_vesting::new(
        clock,
        meme_coin,
        now,
        self.vesting_duration.destroy_some(),
        ctx,
    );

    (sui_coin, memez_vesting)
}

// === OTC Owner Functions ===

public fun set_deadline<Meme>(
    self: &mut MemezOTC<Meme>,
    clock: &Clock,
    deadline: u64,
    ctx: &mut TxContext,
) {
    assert!(deadline > clock.timestamp_ms(), errors::deadline_in_past());
    self.assert_is_owner(ctx);

    self.deadline = option::some(deadline);

    events::update_deadline<Meme>(self.id.to_address(), deadline);
}

public fun set_vesting_duration<Meme>(
    self: &mut MemezOTC<Meme>,
    vesting_duration: u64,
    ctx: &mut TxContext,
) {
    self.assert_is_owner(ctx);

    self.vesting_duration = option::some(vesting_duration);

    events::update_vesting_duration<Meme>(self.id.to_address(), vesting_duration);
}

public fun destroy<Meme>(self: MemezOTC<Meme>, ctx: &mut TxContext): Coin<Meme> {
    self.assert_is_owner(ctx);

    let MemezOTC { id, balance, owner, .. } = self;

    events::destroy<Meme>(id.to_address(), owner);

    id.delete();

    balance.into_coin(ctx)
}

// === Private Functions ===

fun amount_in<Meme>(self: &MemezOTC<Meme>, amount_out: u64): (u64, u64) {
    let price = self.price();

    let amount_in = amount_out.mul_div_up(SUI_SCALAR, price);

    let max_bps = max_bps();

    let amount_with_fee = amount_in.mul_div_up(max_bps, max_bps - self.fee.value());

    (amount_in, amount_with_fee - amount_in)
}

fun amount_out<Meme>(self: &MemezOTC<Meme>, amount_in: u64): (u64, u64) {
    let fee = self.fee.calc_up(amount_in);

    let amount_in_minus_fee = amount_in - fee;

    (amount_in_minus_fee.mul_div_down(self.price(), SUI_SCALAR), fee)
}

fun price<Meme>(self: &MemezOTC<Meme>): u64 {
    self.deposited_meme_amount.mul_div_down(SUI_SCALAR, self.desired_sui_amount)
}

fun buy_internal<Meme>(
    self: &mut MemezOTC<Meme>,
    mut sui_coin: Coin<SUI>,
    ctx: &mut TxContext,
): (Coin<SUI>, Coin<Meme>) {
    let sui_coin_value = sui_coin.value();

    let available_meme_amount = self.balance.value();

    let (amount_out, fee) = self.amount_out(sui_coin_value);

    assert!(amount_out > 0, errors::invalid_buy_amount());
    assert!(available_meme_amount > 0, errors::all_meme_sold());

    if (available_meme_amount >= amount_out) {
        transfer::public_transfer(sui_coin.split(fee, ctx), self.treasury);
        transfer::public_transfer(sui_coin, self.recipient);

        events::buy<Meme>(
            self.id.to_address(),
            sui_coin_value,
            amount_out,
            fee,
            self.vesting_duration,
        );

        (coin::zero(ctx), self.balance.split(amount_out).into_coin(ctx))
    } else {
        let (amount_in, fee) = self.amount_in(available_meme_amount);

        transfer::public_transfer(sui_coin.split(fee, ctx), self.treasury);
        transfer::public_transfer(sui_coin.split(amount_in, ctx), self.recipient);

        events::buy<Meme>(
            self.id.to_address(),
            amount_in,
            amount_out,
            fee,
            self.vesting_duration,
        );

        (sui_coin, self.balance.withdraw_all().into_coin(ctx))
    }
}

fun assert_is_owner<Meme>(otc: &MemezOTC<Meme>, ctx: &TxContext) {
    assert!(otc.owner == ctx.sender(), errors::not_owner());
}

// === Method Aliases ===

use fun u64::mul_div_up as u64.mul_div_up;
use fun u64::mul_div_down as u64.mul_div_down;

// === Test Only Functions ===

#[test_only]
public fun balance<Meme>(otc: &MemezOTC<Meme>): u64 {
    otc.balance.value()
}

#[test_only]
public fun owner<Meme>(otc: &MemezOTC<Meme>): address {
    otc.owner
}

#[test_only]
public fun recipient<Meme>(otc: &MemezOTC<Meme>): address {
    otc.recipient
}

#[test_only]
public fun deposited_meme_amount<Meme>(otc: &MemezOTC<Meme>): u64 {
    otc.deposited_meme_amount
}

#[test_only]
public fun desired_sui_amount<Meme>(otc: &MemezOTC<Meme>): u64 {
    otc.desired_sui_amount
}

#[test_only]
public fun fee<Meme>(otc: &MemezOTC<Meme>): BPS {
    otc.fee
}

#[test_only]
public fun vesting_duration<Meme>(otc: &MemezOTC<Meme>): Option<u64> {
    otc.vesting_duration
}

#[test_only]
public fun deadline<Meme>(otc: &MemezOTC<Meme>): Option<u64> {
    otc.deadline
}

#[test_only]
public fun treasury<Meme>(otc: &MemezOTC<Meme>): address {
    otc.treasury
}

#[test_only]
public fun get_amount_out<Meme>(otc: &MemezOTC<Meme>, amount_in: u64): (u64, u64) {
    otc.amount_out(amount_in)
}

#[test_only]
public fun get_amount_in<Meme>(otc: &MemezOTC<Meme>, amount_out: u64): (u64, u64) {
    otc.amount_in(amount_out)
}
