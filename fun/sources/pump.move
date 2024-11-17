// module memez_fun::memez_pump;
// // === Imports === 

// use std::string::String;

// use sui::{
//     sui::SUI,
//     balance::{Self, Balance},
//     versioned::{Self, Versioned},
//     coin::{Coin, TreasuryCap, CoinMetadata},
// };

// use interest_math::u64;

// use ipx_coin_standard::ipx_coin_standard::{IPXTreasuryStandard, MetadataCap};

// use constant_product::constant_product::get_amount_out;

// use memez_fun::{
//     memez_events,
//     memez_pump_config,
//     memez_migration::Migration,
//     memez_version::CurrentVersion,
//     memez_burn_tax::{Self, BurnTax},
//     memez_config::{Self, MemezConfig},
//     memez_fun::{Self, MemezFun, MemezMigrator},
//     memez_utils::{assert_slippage, destroy_or_burn, assert_coin_has_value},
// };

// // === Constants ===

// const PUMP_STATE_VERSION_V1: u64 = 1;

// // === Errors ===

// const EInvalidVersion: u64 = 0;

// // === Structs ===

// public struct Pump()

// public struct PumpState<phantom Meme> has store {
//     burn_tax: BurnTax,  
//     sui_balance: Balance<SUI>,
//     meme_balance: Balance<Meme>,
//     virtual_liquidity: u64, 
//     target_sui_liquidity: u64,  
//     dev_purchase: Balance<Meme>, 
//     liquidity_provision: Balance<Meme>, 
// }

// // === Public Mutative Functions === 

// #[allow(lint(share_owned))]
// public fun new<Meme, MigrationWitness>(
//     config: &MemezConfig,
//     migration: &Migration,
//     meme_metadata: &CoinMetadata<Meme>,
//     meme_treasury_cap: TreasuryCap<Meme>,
//     creation_fee: Coin<SUI>,
//     first_purchase: Coin<SUI>,
//     metadata_names: vector<String>,
//     metadata_values: vector<String>,
//     version: CurrentVersion,
//     ctx: &mut TxContext
// ): MetadataCap {
//     version.assert_is_valid();
//     config.take_creation_fee(creation_fee);

//     let pump_config = memez_pump_config::get(config);

//     let (ipx_meme_coin_treasury, metadata_cap, mut meme_balance) = memez_config::set_up_treasury(meme_metadata, meme_treasury_cap, ctx);

//     let liquidity_provision = meme_balance.split(pump_config[3]);

//     let pump_state = PumpState<Meme> {
//         burn_tax: memez_burn_tax::new(pump_config[0], pump_config[1], pump_config[2]),  
//         virtual_liquidity: pump_config[1], 
//         target_sui_liquidity: pump_config[2],  
//         dev_purchase: balance::zero(), 
//         liquidity_provision, 
//         sui_balance: balance::zero(),
//         meme_balance,
//     };

//     let mut memez_fun = memez_fun::new<Pump, MigrationWitness, Meme>(
//         migration, 
//         versioned::create(PUMP_STATE_VERSION_V1, pump_state, ctx), 
//         metadata_names, 
//         metadata_values, 
//         ipx_meme_coin_treasury,
//         ctx
//     );

//     if (first_purchase.value() != 0) {
//         let meme_coin = pump(&mut memez_fun, first_purchase, 0, version, ctx);

//         let state = state_mut<Meme>(memez_fun.versioned_mut());

//         state.dev_purchase.join(meme_coin.into_balance());
//     } else {
//         first_purchase.destroy_zero();
//     };

//     memez_fun.share();

//     metadata_cap
// }

// public fun pump<Meme>(
//     self: &mut MemezFun<Pump,Meme>, 
//     sui_coin: Coin<SUI>, 
//     min_amount_out: u64,
//     version: CurrentVersion, 
//     ctx: &mut TxContext
// ): Coin<Meme> {
//     version.assert_is_valid();
//     self.assert_is_bonding();

//     let sui_coin_value = assert_coin_has_value(&sui_coin); 

//     let state = state_mut<Meme>(self.versioned_mut());

//     let meme_balance_value = state.meme_balance.value();

//     let meme_coin_value_out = get_amount_out(
//         sui_coin_value, 
//         state.virtual_liquidity + state.sui_balance.value(), 
//         meme_balance_value
//     );

//     assert_slippage(meme_coin_value_out, min_amount_out);

//     let meme_coin = state.meme_balance.split(meme_coin_value_out).into_coin(ctx);

//     let total_sui_balance = state.sui_balance.join(sui_coin.into_balance());  

//     if (total_sui_balance >= state.target_sui_liquidity)
//         self.set_progress_to_migrating();

//     memez_events::pump<Meme>(self.addy(), sui_coin_value, meme_coin_value_out);

//     meme_coin
// }

// public fun dump<Meme>(
//     self: &mut MemezFun<Auction, Meme>, 
//     clock: &Clock,
//     treasury_cap: &mut IPXTreasuryStandard, 
//     mut meme_coin: Coin<Meme>, 
//     min_amount_out: u64,
//     version: CurrentVersion, 
//     ctx: &mut TxContext
// ): Coin<SUI> {
//     version.assert_is_valid();
//     self.assert_is_bonding();

//     let meme_coin_value = assert_coin_has_value(&meme_coin);

//     let state = state_mut<Meme>(self.versioned_mut());

//     let meme_balance_value = state.meme_balance.value();

//     let sui_balance_value = state.sui_balance.value(); 

//     let sui_virtual_liquidity = state.virtual_liquidity + sui_balance_value;

//     let pre_tax_sui_value_out = get_amount_out(
//         meme_coin_value, 
//         meme_balance_value, 
//         sui_virtual_liquidity
//     ); 

//     let dynamic_burn_tax = state.burn_tax.calculate(sui_virtual_liquidity - pre_tax_sui_value_out);

//     let meme_fee_value = u64::mul_div_up(meme_coin_value, dynamic_burn_tax, POW_9);

//     treasury_cap.burn(meme_coin.split(meme_fee_value, ctx));

//     let post_tax_sui_value_out = get_amount_out(
//         meme_coin_value - meme_fee_value, 
//         meme_balance_value, 
//         sui_virtual_liquidity
//     );

//     state.meme_balance.join(meme_coin.into_balance()); 

//     let sui_coin_amount_out = u64::min(post_tax_sui_value_out, sui_balance_value);

//     assert_slippage(sui_coin_amount_out, min_amount_out);

//     let sui_coin = state.sui_balance.split(sui_coin_amount_out).into_coin(ctx);

//     memez_events::dump<Meme>(
//         self.addy(), 
//         post_tax_sui_value_out, 
//         meme_coin_value, 
//         meme_fee_value
//     );

//     sui_coin
// }

// // === Private Functions === 

// fun state<Meme>(versioned: &mut Versioned): &PumpState<Meme> {
//     maybe_upgrade_state_to_latest(versioned);
//     versioned.load_value()
// }

// fun state_mut<Meme>(versioned: &mut Versioned): &mut PumpState<Meme> {
//     maybe_upgrade_state_to_latest(versioned);
//     versioned.load_value_mut()
// }

// #[allow(unused_mut_parameter)]
// fun maybe_upgrade_state_to_latest(versioned: &mut Versioned) {
//     assert!(versioned.version() == PUMP_STATE_VERSION_V1, EInvalidVersion);
// }