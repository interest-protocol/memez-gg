// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

module memez_presale::memez_utils;

use interest_bps::bps;
use sui::{balance::Balance, coin::Coin};

// === Public Package Functions ===

public(package) macro fun assert_coin_has_value<$T>($coin: &Coin<$T>): u64 {
    let coin = $coin;
    let value = coin.value();
    assert!(value > 0, memez_presale::memez_errors::coin_has_no_value!());
    value
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
        memez_presale::memez_errors::invalid_bps_percentages!(),
    );
}
