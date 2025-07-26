// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

module memez_fun::memez_utils;

use interest_bps::bps::{Self, BPS};
use ipx_coin_standard::ipx_coin_standard::{Self, MetadataCap};
use sui::{balance::Balance, coin::{Coin, TreasuryCap}};

// === Public Package Functions ===

public(package) macro fun assert_coin_has_value<$T>($coin: &Coin<$T>): u64 {
    let coin = $coin;
    let value = coin.value();
    assert!(value > 0, memez_fun::memez_errors::zero_coin!());
    value
}

public(package) macro fun assert_slippage($amount: u64, $minimum_expected: u64) {
    let amount = $amount;
    let minimum_expected = $minimum_expected;
    assert!(amount >= minimum_expected, memez_fun::memez_errors::slippage!());
}

public(package) macro fun destroy_or_burn<$Meme>(
    $balance: &mut Balance<$Meme>,
    $ctx: &mut TxContext,
) {
    let balance = $balance;
    let ctx = $ctx;
    let bal = balance.withdraw_all();

    if (bal.value() == 0) bal.destroy_zero()
    else transfer::public_transfer(bal.into_coin(ctx), @0x0);
}

public(package) macro fun coin_destroy_or_burn<$Meme>($coin: Coin<$Meme>) {
    let coin = $coin;
    if (coin.value() == 0) coin.destroy_zero() else transfer::public_transfer(coin, @0x0);
}

public(package) macro fun destroy_or_return<$Meme>($coin: Coin<$Meme>, $ctx: &TxContext) {
    let coin = $coin;
    let ctx = $ctx;
    if (coin.value() == 0) coin.destroy_zero() else transfer::public_transfer(coin, ctx.sender());
}

public(package) macro fun validate_bps($percentages: vector<u64>) {
    let percentages = $percentages;
    assert!(
        percentages.fold!(0, |acc, bps| acc + bps) == bps::max_value!(),
        memez_fun::memez_errors::invalid_percentages!(),
    );
}

public(package) macro fun new_treasury<$Meme>(
    $mut_meme_treasury_cap: TreasuryCap<$Meme>,
    $total_supply: u64,
    $ctx: &mut TxContext,
): (address, MetadataCap, Balance<$Meme>) {
    let mut meme_treasury_cap = $mut_meme_treasury_cap;
    let total_supply = $total_supply;
    let ctx = $ctx;
    assert!(
        meme_treasury_cap.total_supply() == 0,
        memez_fun::memez_errors::pre_mint_not_allowed!(),
    );
    assert!(total_supply != 0, memez_fun::memez_errors::zero_total_supply!());

    let meme_balance = meme_treasury_cap.mint_balance(
        total_supply,
    );

    let (mut ipx_treasury_standard, mut witness) = ipx_coin_standard::new(
        meme_treasury_cap,
        ctx,
    );

    witness.set_maximum_supply(total_supply);

    witness.allow_public_burn(
        &mut ipx_treasury_standard,
    );

    let treasury_address = object::id_address(
        &ipx_treasury_standard,
    );

    let metadata_cap = witness.create_metadata_cap(ctx);

    ipx_treasury_standard.destroy_witness<$Meme>(witness);

    transfer::public_share_object(
        ipx_treasury_standard,
    );

    (treasury_address, metadata_cap, meme_balance)
}

public(package) macro fun send_referrer_fee<$CoinType>(
    $coin: &mut Coin<$CoinType>,
    $referrer: Option<address>,
    $fee: BPS,
    $ctx: &mut TxContext,
): u64 {
    let coin = $coin;
    let referrer = $referrer;
    let fee = $fee;
    let ctx = $ctx;

    if (referrer.is_none()) return 0;

    let payment_value = fee.calc_up(coin.value());

    if (payment_value == 0) return 0;

    let payment = coin.split(payment_value, ctx);

    transfer::public_transfer(payment, referrer.destroy_some());

    payment_value
}
