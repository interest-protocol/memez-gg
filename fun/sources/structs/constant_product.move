module memez_fun::memez_constant_product;

use constant_product::constant_product::get_amount_out;
use interest_math::u64;
use ipx_coin_standard::ipx_coin_standard::IPXTreasuryStandard;
use memez_fun::{
    memez_burner::{Self, MemezBurner},
    memez_events,
    memez_fees::Fee,
    memez_utils::{assert_slippage, assert_coin_has_value, pow_9}
};
use sui::{balance::{Self, Balance}, coin::Coin, sui::SUI};

// === Structs ===

public struct MemezConstantProduct<phantom Meme> has store {
    memez_fun: address,
    virtual_liquidity: u64,
    target_sui_liquidity: u64,
    sui_balance: Balance<SUI>,
    meme_balance: Balance<Meme>,
    burn_model: MemezBurner,
    swap_fee: Fee,
}

// === Public Package Functions ===

public(package) fun new<Meme>(
    virtual_liquidity: u64,
    target_sui_liquidity: u64,
    meme_balance: Balance<Meme>,
    swap_fee: Fee,
    burn_tax: u64,
): MemezConstantProduct<Meme> {
    MemezConstantProduct {
        memez_fun: @0x0,
        virtual_liquidity,
        target_sui_liquidity,
        sui_balance: balance::zero(),
        meme_balance,
        burn_model: memez_burner::new(vector[burn_tax, virtual_liquidity, target_sui_liquidity]),
        swap_fee,
    }
}

public(package) fun set_memez_fun<Meme>(self: &mut MemezConstantProduct<Meme>, memez_fun: address) {
    self.memez_fun = memez_fun;
}

public(package) fun pump<Meme>(
    self: &mut MemezConstantProduct<Meme>,
    mut sui_coin: Coin<SUI>,
    min_amount_out: u64,
    ctx: &mut TxContext,
): (bool, Coin<Meme>) {
    let swap_fee = self.swap_fee.take(&mut sui_coin, ctx);

    let sui_coin_value = assert_coin_has_value(&sui_coin);

    let meme_balance_value = self.meme_balance.value();

    let meme_coin_value_out = get_amount_out(
        sui_coin_value,
        self.virtual_liquidity + self.sui_balance.value(),
        meme_balance_value,
    );

    assert_slippage(meme_coin_value_out, min_amount_out);

    let meme_coin = self.meme_balance.split(meme_coin_value_out).into_coin(ctx);

    let total_sui_balance = self.sui_balance.join(sui_coin.into_balance());

    memez_events::pump<Meme>(self.memez_fun, sui_coin_value, meme_coin_value_out, swap_fee);

    (total_sui_balance >= self.target_sui_liquidity, meme_coin)
}

public(package) fun dump<Meme>(
    self: &mut MemezConstantProduct<Meme>,
    treasury_cap: &mut IPXTreasuryStandard,
    mut meme_coin: Coin<Meme>,
    min_amount_out: u64,
    ctx: &mut TxContext,
): Coin<SUI> {
    let swap_fee = self.swap_fee.take(&mut meme_coin, ctx);

    let meme_coin_value = assert_coin_has_value(&meme_coin);

    let meme_balance_value = self.meme_balance.value();

    let sui_balance_value = self.sui_balance.value();

    let sui_virtual_liquidity = self.virtual_liquidity + sui_balance_value;

    let pre_tax_sui_value_out = get_amount_out(
        meme_coin_value,
        meme_balance_value,
        sui_virtual_liquidity,
    );

    let dynamic_burn_tax = self.burn_model.calculate(sui_virtual_liquidity - pre_tax_sui_value_out);
    let meme_burn_fee_value = u64::mul_div_up(meme_coin_value, dynamic_burn_tax, pow_9());

    if (dynamic_burn_tax != 0) treasury_cap.burn(meme_coin.split(meme_burn_fee_value, ctx));

    let meme_coin_value = assert_coin_has_value(&meme_coin);

    let meme_balance_value = self.meme_balance.value();

    let sui_balance_value = self.sui_balance.value();

    let sui_virtual_liquidity = self.virtual_liquidity + sui_balance_value;

    let sui_value_out = get_amount_out(
        meme_coin_value,
        meme_balance_value,
        sui_virtual_liquidity,
    );

    self.meme_balance.join(meme_coin.into_balance());

    let sui_coin_amount_out = sui_value_out.min(sui_balance_value);

    assert_slippage(sui_coin_amount_out, min_amount_out);

    let sui_coin = self.sui_balance.split(sui_coin_amount_out).into_coin(ctx);

    memez_events::dump<Meme>(
        self.memez_fun,
        sui_value_out,
        meme_coin_value,
        swap_fee,
        meme_burn_fee_value,
    );

    sui_coin
}

public(package) fun pump_amount<Meme>(
    self: &MemezConstantProduct<Meme>,
    amount_in: u64,
    extra_meme_amount: u64,
): vector<u64> {
    if (amount_in == 0) return vector[0, 0];

    let swap_fee = self.swap_fee.calculate(amount_in);

    let amount_out = get_amount_out(
        amount_in - swap_fee,
        self.virtual_liquidity + self.sui_balance.value(),
        self.meme_balance.value() + extra_meme_amount,
    );

    vector[amount_out, swap_fee]
}

public(package) fun dump_amount<Meme>(
    self: &MemezConstantProduct<Meme>,
    amount_in: u64,
    extra_meme_amount: u64,
): vector<u64> {
    if (amount_in == 0) return vector[0, 0, 0, 0];

    let meme_balance_value = self.meme_balance.value() + extra_meme_amount;

    let sui_balance_value = self.sui_balance.value();

    let sui_virtual_liquidity = self.virtual_liquidity + sui_balance_value;

    let swap_fee = self.swap_fee.calculate(amount_in);

    let amount_in_minus_swap_fee = amount_in - swap_fee;

    let pre_tax_sui_value_out = get_amount_out(
        amount_in_minus_swap_fee,
        meme_balance_value,
        sui_virtual_liquidity,
    );

    let dynamic_burn_tax = self.burn_model.calculate(sui_virtual_liquidity - pre_tax_sui_value_out);

    let meme_burn_fee_value = u64::mul_div_up(amount_in_minus_swap_fee, dynamic_burn_tax, pow_9());

    if (dynamic_burn_tax == 0) {
        return vector[
            pre_tax_sui_value_out.min(sui_balance_value),
            pre_tax_sui_value_out,
            swap_fee,
            meme_burn_fee_value,
        ]
    };

    let post_tax_sui_value_out = get_amount_out(
        amount_in_minus_swap_fee - meme_burn_fee_value,
        meme_balance_value,
        sui_virtual_liquidity,
    );

    vector[
        post_tax_sui_value_out.min(sui_balance_value),
        post_tax_sui_value_out,
        swap_fee,
        meme_burn_fee_value,
    ]
}

public(package) fun virtual_liquidity<Meme>(self: &MemezConstantProduct<Meme>): u64 {
    self.virtual_liquidity
}

public(package) fun target_sui_liquidity<Meme>(self: &MemezConstantProduct<Meme>): u64 {
    self.target_sui_liquidity
}

public(package) fun sui_balance<Meme>(self: &MemezConstantProduct<Meme>): &Balance<SUI> {
    &self.sui_balance
}

public(package) fun burner<Meme>(self: &MemezConstantProduct<Meme>): MemezBurner {
    self.burn_model
}

public(package) fun meme_balance<Meme>(self: &MemezConstantProduct<Meme>): &Balance<Meme> {
    &self.meme_balance
}

public(package) fun sui_balance_mut<Meme>(
    self: &mut MemezConstantProduct<Meme>,
): &mut Balance<SUI> {
    &mut self.sui_balance
}

public(package) fun meme_balance_mut<Meme>(
    self: &mut MemezConstantProduct<Meme>,
): &mut Balance<Meme> {
    &mut self.meme_balance
}

// === Test Only Functions ===

#[test_only]
public fun memez_fun<Meme>(self: &MemezConstantProduct<Meme>): address {
    self.memez_fun
}
