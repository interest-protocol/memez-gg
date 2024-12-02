module memez_fun::memez_utils;

use interest_bps::bps;
use ipx_coin_standard::ipx_coin_standard::{Self, MetadataCap};
use memez_fun::memez_errors;
use sui::{balance::Balance, coin::{Coin, TreasuryCap}};

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

public(package) fun assert_slippage(amount: u64, minimum_expected: u64) {
    assert!(amount >= minimum_expected, memez_errors::slippage());
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

public(package) fun validate_bps(percentages: vector<u64>) {
    assert!(
        percentages.fold!(0, |acc, bps| acc + bps) == bps::max_bps(),
        memez_errors::invalid_percentages(),
    );
}

#[allow(lint(share_owned))]
public(package) fun new_treasury<Meme>(
    mut meme_treasury_cap: TreasuryCap<Meme>,
    total_supply: u64,
    ctx: &mut TxContext,
): (address, MetadataCap, Balance<Meme>) {
    assert!(meme_treasury_cap.total_supply() == 0, memez_errors::pre_mint_not_allowed());
    assert!(total_supply != 0, memez_errors::zero_total_supply());

    let meme_balance = meme_treasury_cap.mint_balance(
        total_supply,
    );

    let (mut ipx_treasury_standard, mut cap_witness) = ipx_coin_standard::new(
        meme_treasury_cap,
        ctx,
    );

    cap_witness.add_burn_capability(
        &mut ipx_treasury_standard,
    );

    let treasury_address = object::id_address(
        &ipx_treasury_standard,
    );

    let metadata_cap = cap_witness.create_metadata_cap(ctx);

    ipx_treasury_standard.destroy_cap_witness(cap_witness);

    transfer::public_share_object(
        ipx_treasury_standard,
    );

    (treasury_address, metadata_cap, meme_balance)
}
