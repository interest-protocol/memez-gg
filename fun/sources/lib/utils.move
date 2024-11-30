module memez_fun::memez_utils;

use interest_bps::bps;
use memez_fun::memez_errors;
use sui::{balance::Balance, coin::Coin};

// === Constants ===

const DEAD_ADDRESS: address = @0x0;

const POW_9: u64 = 1__000_000_000;

// === Public Package Functions ===

public(package) fun pow_9(): u64 {
    POW_9
}

public(package) fun assert_coin_has_value<T>(coin: &Coin<T>): u64 {
    let value = coin.value();
    assert!(value > 0, memez_errors::zero_coin());
    value
}

public(package) fun destroy_or_burn<Meme>(balance: &mut Balance<Meme>, ctx: &mut TxContext) {
    let bal = balance.withdraw_all();

    if (bal.value() == 0) bal.destroy_zero()
    else transfer::public_transfer(bal.into_coin(ctx), DEAD_ADDRESS);
}

#[allow(lint(self_transfer))]
public(package) fun destroy_or_return<Meme>(coin: Coin<Meme>, ctx: &TxContext) {
    if (coin.value() == 0) coin.destroy_zero()
    else transfer::public_transfer(coin, ctx.sender());
}

public(package) fun assert_slippage(amount: u64, minimum_expected: u64) {
    assert!(amount >= minimum_expected, memez_errors::slippage());
}

public(package) fun validate_bps(percentages: vector<u64>) {
    assert!(
        percentages.fold!(0, |acc, bps| acc + bps) == bps::max_bps(),
        memez_errors::invalid_percentages(),
    );
}
