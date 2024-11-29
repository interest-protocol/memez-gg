/*                                     
        GGGGGGGGGGGGG        GGGGGGGGGGGGG     
     GGG::::::::::::G     GGG::::::::::::G     
   GG:::::::::::::::G   GG:::::::::::::::G     
  G:::::GGGGGGGG::::G  G:::::GGGGGGGG::::G     
 G:::::G       GGGGGG G:::::G       GGGGGG     
G:::::G              G:::::G                   
G:::::G              G:::::G                   
G:::::G    GGGGGGGGGGG:::::G    GGGGGGGGGG     
G:::::G    G::::::::GG:::::G    G::::::::G     
G:::::G    GGGGG::::GG:::::G    GGGGG::::G     
G:::::G        G::::GG:::::G        G::::G     
 G:::::G       G::::G G:::::G       G::::G     
  G:::::GGGGGGGG::::G  G:::::GGGGGGGG::::G     
   GG:::::::::::::::G   GG:::::::::::::::G     
     GGG::::::GGG:::G     GGG::::::GGG:::G     
        GGGGGG   GGGG        GGGGGG   GGGG                                           
*/
module memez_fun::memez_pump;

use ipx_coin_standard::ipx_coin_standard::{IPXTreasuryStandard, MetadataCap};
use memez_fun::{
    memez_config::{Self, MemezConfig},
    memez_constant_product::{Self, MemezConstantProduct},
    memez_errors,
    memez_fee_model::FeeModel,
    memez_fun::{Self, MemezFun, MemezMigrator},
    memez_migrator_list::MemezMigratorList,
    memez_pump_config,
    memez_token_cap::{Self, MemezTokenCap},
    memez_utils::{destroy_or_burn, destroy_or_return},
    memez_version::CurrentVersion
};
use std::string::String;
use sui::{
    balance::{Self, Balance},
    coin::{Coin, TreasuryCap},
    sui::SUI,
    token::Token,
    versioned::{Self, Versioned}
};

// === Constants ===

const PUMP_STATE_VERSION_V1: u64 = 1;

// === Structs ===

public struct Pump()

public struct PumpState<phantom Meme> has store {
    dev_purchase: Balance<Meme>,
    liquidity_provision: Balance<Meme>,
    constant_product: MemezConstantProduct<Meme>,
    meme_token_cap: Option<MemezTokenCap<Meme>>,
    fee_model: FeeModel,
}

// === Public Mutative Functions ===

#[allow(lint(share_owned))]
public fun new<Meme, MigrationWitness, FeeModelKey>(
    config: &MemezConfig,
    migrator_list: &MemezMigratorList,
    meme_treasury_cap: TreasuryCap<Meme>,
    mut creation_fee: Coin<SUI>,
    total_supply: u64,
    is_token: bool,
    first_purchase: Coin<SUI>,
    metadata_names: vector<String>,
    metadata_values: vector<String>,
    version: CurrentVersion,
    ctx: &mut TxContext,
): MetadataCap {
    version.assert_is_valid();

    let fee_model = config.get_model<FeeModelKey>();

    fee_model.new_fee().send(&mut creation_fee, ctx);

    creation_fee.destroy_or_return(ctx);

    let pump_config = memez_pump_config::get(config, total_supply);

    let meme_token_cap = if (is_token) option::some(memez_token_cap::new(&meme_treasury_cap, ctx))
    else option::none();

    let (
        ipx_meme_coin_treasury,
        metadata_cap,
        mut meme_balance,
    ) = memez_config::set_up_meme_treasury(meme_treasury_cap, total_supply, ctx);

    let liquidity_provision = meme_balance.split(pump_config[3]);

    let pump_state = PumpState<Meme> {
        dev_purchase: balance::zero(),
        liquidity_provision,
        constant_product: memez_constant_product::new(
            pump_config[1],
            pump_config[2],
            meme_balance,
            pump_config[0],
        ),
        meme_token_cap,
        fee_model,
    };

    let mut memez_fun = memez_fun::new<Pump, MigrationWitness, Meme>(
        migrator_list,
        versioned::create(PUMP_STATE_VERSION_V1, pump_state, ctx),
        is_token,
        metadata_names,
        metadata_values,
        ipx_meme_coin_treasury,
        ctx,
    );

    let memez_fun_address = memez_fun.addy();

    let state = memez_fun.state_mut();

    state.constant_product.set_memez_fun(memez_fun_address);

    if (first_purchase.value() != 0) {
        let meme_coin = pump_unchecked(
            &mut memez_fun,
            first_purchase,
            0,
            ctx,
        );

        let state = memez_fun.state_mut();

        state.dev_purchase.join(meme_coin.into_balance());
    } else first_purchase.destroy_zero();

    memez_fun.share();

    metadata_cap
}

public fun pump<Meme>(
    self: &mut MemezFun<Pump, Meme>,
    sui_coin: Coin<SUI>,
    min_amount_out: u64,
    version: CurrentVersion,
    ctx: &mut TxContext,
): Coin<Meme> {
    version.assert_is_valid();
    self.assert_uses_coin();
    self.assert_is_bonding();

    pump_unchecked(self, sui_coin, min_amount_out, ctx)
}

public fun pump_token<Meme>(
    self: &mut MemezFun<Pump, Meme>,
    sui_coin: Coin<SUI>,
    min_amount_out: u64,
    version: CurrentVersion,
    ctx: &mut TxContext,
): Token<Meme> {
    version.assert_is_valid();
    self.assert_uses_token();
    self.assert_is_bonding();

    let state = self.state_mut();

    let (start_migrating, meme_coin) = state
        .constant_product
        .pump(
            sui_coin,
            min_amount_out,
            ctx,
        );

    let meme_token = state.token_cap().from_coin(meme_coin, ctx);

    if (start_migrating) self.set_progress_to_migrating();

    meme_token
}

public fun dump<Meme>(
    self: &mut MemezFun<Pump, Meme>,
    treasury_cap: &mut IPXTreasuryStandard,
    meme_coin: Coin<Meme>,
    min_amount_out: u64,
    version: CurrentVersion,
    ctx: &mut TxContext,
): Coin<SUI> {
    version.assert_is_valid();
    self.assert_uses_coin();
    self.assert_is_bonding();

    self
        .state_mut()
        .constant_product
        .burn_and_dump(
            treasury_cap,
            meme_coin,
            min_amount_out,
            ctx,
        )
}

public fun dump_token<Meme>(
    self: &mut MemezFun<Pump, Meme>,
    treasury_cap: &mut IPXTreasuryStandard,
    meme_token: Token<Meme>,
    min_amount_out: u64,
    version: CurrentVersion,
    ctx: &mut TxContext,
): Coin<SUI> {
    version.assert_is_valid();
    self.assert_uses_token();
    self.assert_is_bonding();

    let state = self.state_mut();

    let meme_coin = state.token_cap().to_coin(meme_token, ctx);

    state
        .constant_product
        .burn_and_dump(
            treasury_cap,
            meme_coin,
            min_amount_out,
            ctx,
        )
}

public fun migrate<Meme>(
    self: &mut MemezFun<Pump, Meme>,
    version: CurrentVersion,
    ctx: &mut TxContext,
): MemezMigrator<Meme> {
    version.assert_is_valid();
    self.assert_is_migrating();

    let state = self.state_mut();

    let sui_balance = state.constant_product.sui_balance_mut().withdraw_all();

    let liquidity_provision = state.liquidity_provision.withdraw_all();

    state.constant_product.meme_balance_mut().destroy_or_burn(ctx);

    let mut sui_coin = sui_balance.into_coin(ctx);

    state.fee_model.migration_fee().send(&mut sui_coin, ctx);

    self.migrate(sui_coin.into_balance(), liquidity_provision)
}

public fun dev_claim<Meme>(
    self: &mut MemezFun<Pump, Meme>,
    version: CurrentVersion,
    ctx: &mut TxContext,
): Coin<Meme> {
    version.assert_is_valid();

    self.assert_migrated();
    self.assert_is_dev(ctx);

    let state = self.state_mut();

    state.dev_purchase.withdraw_all().into_coin(ctx)
}

public fun to_coin<Meme>(
    self: &mut MemezFun<Pump, Meme>,
    meme_token: Token<Meme>,
    ctx: &mut TxContext,
): Coin<Meme> {
    self.assert_migrated();
    self.state_mut().token_cap().to_coin(meme_token, ctx)
}

// === View Functions for FE ===

#[allow(unused_function)]
fun pump_amount<Meme>(self: &mut MemezFun<Pump, Meme>, amount_in: u64): u64 {
    let state = self.state();

    state
        .constant_product
        .pump_amount(
            amount_in,
            0,
        )
}

#[allow(unused_function)]
fun dump_amount<Meme>(self: &mut MemezFun<Pump, Meme>, amount_in: u64): (u64, u64, u64) {
    let state = self.state();

    state.constant_product.burn_and_dump_amount(amount_in, 0)
}

// === Private Functions ===

fun pump_unchecked<Meme>(
    self: &mut MemezFun<Pump, Meme>,
    sui_coin: Coin<SUI>,
    min_amount_out: u64,
    ctx: &mut TxContext,
): Coin<Meme> {
    let (start_migrating, meme_coin) = self
        .state_mut()
        .constant_product
        .pump(
            sui_coin,
            min_amount_out,
            ctx,
        );

    if (start_migrating) self.set_progress_to_migrating();

    meme_coin
}

fun token_cap<Meme>(state: &PumpState<Meme>): &MemezTokenCap<Meme> {
    state.meme_token_cap.borrow()
}

fun state<Meme>(memez_fun: &mut MemezFun<Pump, Meme>): &PumpState<Meme> {
    let versioned = memez_fun.versioned_mut();
    maybe_upgrade_state_to_latest(versioned);
    versioned.load_value()
}

fun state_mut<Meme>(memez_fun: &mut MemezFun<Pump, Meme>): &mut PumpState<Meme> {
    let versioned = memez_fun.versioned_mut();
    maybe_upgrade_state_to_latest(versioned);
    versioned.load_value_mut()
}

#[allow(unused_mut_parameter)]
fun maybe_upgrade_state_to_latest(versioned: &mut Versioned) {
    assert!(
        versioned.version() == PUMP_STATE_VERSION_V1,
        memez_errors::outdated_pump_state_version(),
    );
}

// === Aliases ===

use fun state as MemezFun.state;
use fun state_mut as MemezFun.state_mut;
use fun destroy_or_burn as Balance.destroy_or_burn;
use fun destroy_or_return as Coin.destroy_or_return;

// === Public Test Only Functions ===

#[test_only]
public fun liquidity_provision<Meme>(self: &mut MemezFun<Pump, Meme>): u64 {
    let state = self.state();
    state.liquidity_provision.value()
}

#[test_only]
public fun constant_product_mut<Meme>(
    self: &mut MemezFun<Pump, Meme>,
): &mut MemezConstantProduct<Meme> {
    &mut self.state_mut().constant_product
}

#[test_only]
public fun dev_purchase<Meme>(self: &mut MemezFun<Pump, Meme>): u64 {
    self.state_mut().dev_purchase.value()
}
