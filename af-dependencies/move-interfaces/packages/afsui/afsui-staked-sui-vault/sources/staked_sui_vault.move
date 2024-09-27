// Copyright (c) Aftermath Technologies, Inc.
// SPDX-License-Identifier: Apache-2.0

module lsd::staked_sui_vault {
	struct AdminCap has store, key {
		id: sui::object::UID
	}

	struct CreateStakedSuiVaultCap has store, key {
		id: sui::object::UID
	}

	struct STAKED_SUI_VAULT has drop {
		dummy_field: bool
	}

	struct StakedSuiVault has key {
		id: sui::object::UID,
		version: u64
	}

	fun init(
		_arg0: lsd::staked_sui_vault::STAKED_SUI_VAULT,
		_arg1: &mut sui::tx_context::TxContext
	)
	{
		abort 0
	}

	public fun afsui_to_sui_exchange_rate(
		_arg0: &lsd::staked_sui_vault::StakedSuiVault,
		_arg1: &safe::safe::Safe<sui::coin::TreasuryCap<afsui::afsui::AFSUI>>
	): u128
	{
		abort 0
	}

	public fun afsui_to_sui(
		_arg0: &lsd::staked_sui_vault::StakedSuiVault,
		_arg1: &safe::safe::Safe<sui::coin::TreasuryCap<afsui::afsui::AFSUI>>,
		_arg2: u64
	): u64
	{
		abort 0
	}

	public fun sui_to_afsui_exchange_rate(
		_arg0: &lsd::staked_sui_vault::StakedSuiVault,
		_arg1: &safe::safe::Safe<sui::coin::TreasuryCap<afsui::afsui::AFSUI>>
	): u128
	{
		abort 0
	}

	public fun sui_to_afsui(
		_arg0: &lsd::staked_sui_vault::StakedSuiVault,
		_arg1: &safe::safe::Safe<sui::coin::TreasuryCap<afsui::afsui::AFSUI>>,
		_arg2: u64
	): u64
	{
		abort 0
	}

	public fun total_sui_amount(
		_arg0: &lsd::staked_sui_vault::StakedSuiVault
	): u64
	{
		abort 0
	}

	public fun total_rewards_amount(
		_arg0: &lsd::staked_sui_vault::StakedSuiVault
	): u64
	{
		abort 0
	}

	public fun epoch_was_changed(
		_arg0: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg1: &mut safe::safe::Safe<sui::coin::TreasuryCap<afsui::afsui::AFSUI>>,
		_arg2: &mut sui_system::sui_system::SuiSystemState,
		_arg3: &afsui_referral_vault::referral_vault::ReferralVault,
		_arg4: &mut afsui_treasury::treasury::Treasury,
		_arg5: u64,
		_arg6: &mut sui::tx_context::TxContext
	)
	{
		abort 0
	}

	public fun add_crank_incentives(
		_arg0: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg1: sui::coin::Coin<sui::sui::SUI>
	)
	{
		abort 0
	}

	public fun request_stake(
		_arg0: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg1: &mut safe::safe::Safe<sui::coin::TreasuryCap<afsui::afsui::AFSUI>>,
		_arg2: &mut sui_system::sui_system::SuiSystemState,
		_arg3: &afsui_referral_vault::referral_vault::ReferralVault,
		_arg4: sui::coin::Coin<sui::sui::SUI>,
		_arg5: address,
		_arg6: &mut sui::tx_context::TxContext
	): sui::coin::Coin<afsui::afsui::AFSUI>
	{
		abort 0
	}

	entry fun request_stake_and_keep(
		_arg0: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg1: &mut safe::safe::Safe<sui::coin::TreasuryCap<afsui::afsui::AFSUI>>,
		_arg2: &mut sui_system::sui_system::SuiSystemState,
		_arg3: &afsui_referral_vault::referral_vault::ReferralVault,
		_arg4: sui::coin::Coin<sui::sui::SUI>,
		_arg5: address,
		_arg6: &mut sui::tx_context::TxContext
	)
	{
		abort 0
	}

	public fun request_stake_vec(
		_arg0: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg1: &mut safe::safe::Safe<sui::coin::TreasuryCap<afsui::afsui::AFSUI>>,
		_arg2: &mut sui_system::sui_system::SuiSystemState,
		_arg3: &afsui_referral_vault::referral_vault::ReferralVault,
		_arg4: vector<sui::coin::Coin<sui::sui::SUI>>,
		_arg5: address,
		_arg6: &mut sui::tx_context::TxContext
	): sui::coin::Coin<afsui::afsui::AFSUI>
	{
		abort 0
	}

	entry fun request_stake_vec_and_keep(
		_arg0: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg1: &mut safe::safe::Safe<sui::coin::TreasuryCap<afsui::afsui::AFSUI>>,
		_arg2: &mut sui_system::sui_system::SuiSystemState,
		_arg3: &afsui_referral_vault::referral_vault::ReferralVault,
		_arg4: vector<sui::coin::Coin<sui::sui::SUI>>,
		_arg5: address,
		_arg6: &mut sui::tx_context::TxContext
	)
	{
		abort 0
	}

	public fun request_stake_staked_sui(
		_arg0: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg1: &mut safe::safe::Safe<sui::coin::TreasuryCap<afsui::afsui::AFSUI>>,
		_arg2: &mut sui_system::sui_system::SuiSystemState,
		_arg3: &afsui_referral_vault::referral_vault::ReferralVault,
		_arg4: sui_system::staking_pool::StakedSui,
		_arg5: address,
		_arg6: &mut sui::tx_context::TxContext
	): sui::coin::Coin<afsui::afsui::AFSUI>
	{
		abort 0
	}

	entry fun request_stake_staked_sui_and_keep(
		_arg0: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg1: &mut safe::safe::Safe<sui::coin::TreasuryCap<afsui::afsui::AFSUI>>,
		_arg2: &mut sui_system::sui_system::SuiSystemState,
		_arg3: &afsui_referral_vault::referral_vault::ReferralVault,
		_arg4: sui_system::staking_pool::StakedSui,
		_arg5: address,
		_arg6: &mut sui::tx_context::TxContext
	)
	{
		abort 0
	}

	public fun request_stake_staked_sui_vec(
		_arg0: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg1: &mut safe::safe::Safe<sui::coin::TreasuryCap<afsui::afsui::AFSUI>>,
		_arg2: &mut sui_system::sui_system::SuiSystemState,
		_arg3: &afsui_referral_vault::referral_vault::ReferralVault,
		_arg4: vector<sui_system::staking_pool::StakedSui>,
		_arg5: address,
		_arg6: &mut sui::tx_context::TxContext
	): sui::coin::Coin<afsui::afsui::AFSUI>
	{
		abort 0
	}

	entry fun request_stake_staked_sui_vec_and_keep(
		_arg0: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg1: &mut safe::safe::Safe<sui::coin::TreasuryCap<afsui::afsui::AFSUI>>,
		_arg2: &mut sui_system::sui_system::SuiSystemState,
		_arg3: &afsui_referral_vault::referral_vault::ReferralVault,
		_arg4: vector<sui_system::staking_pool::StakedSui>,
		_arg5: address,
		_arg6: &mut sui::tx_context::TxContext
	)
	{
		abort 0
	}

	public fun request_unstake(
		_arg0: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg1: &mut safe::safe::Safe<sui::coin::TreasuryCap<afsui::afsui::AFSUI>>,
		_arg2: sui::coin::Coin<afsui::afsui::AFSUI>,
		_arg3: &mut sui::tx_context::TxContext
	)
	{
		abort 0
	}

	public fun request_unstake_vec(
		_arg0: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg1: &mut safe::safe::Safe<sui::coin::TreasuryCap<afsui::afsui::AFSUI>>,
		_arg2: vector<sui::coin::Coin<afsui::afsui::AFSUI>>,
		_arg3: &mut sui::tx_context::TxContext
	)
	{
		abort 0
	}

	public fun add_atomic_unstake_sui_reserves(
		_arg0: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg1: sui::coin::Coin<sui::sui::SUI>
	)
	{
		abort 0
	}

	public fun request_unstake_atomic(
		_arg0: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg1: &safe::safe::Safe<sui::coin::TreasuryCap<afsui::afsui::AFSUI>>,
		_arg2: &afsui_referral_vault::referral_vault::ReferralVault,
		_arg3: &mut afsui_treasury::treasury::Treasury,
		_arg4: sui::coin::Coin<afsui::afsui::AFSUI>,
		_arg5: &mut sui::tx_context::TxContext
	): sui::coin::Coin<sui::sui::SUI>
	{
		abort 0
	}

	entry fun request_unstake_atomic_and_keep(
		_arg0: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg1: &safe::safe::Safe<sui::coin::TreasuryCap<afsui::afsui::AFSUI>>,
		_arg2: &afsui_referral_vault::referral_vault::ReferralVault,
		_arg3: &mut afsui_treasury::treasury::Treasury,
		_arg4: sui::coin::Coin<afsui::afsui::AFSUI>,
		_arg5: &mut sui::tx_context::TxContext
	)
	{
		abort 0
	}

	public fun request_unstake_vec_atomic(
		_arg0: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg1: &safe::safe::Safe<sui::coin::TreasuryCap<afsui::afsui::AFSUI>>,
		_arg2: &afsui_referral_vault::referral_vault::ReferralVault,
		_arg3: &mut afsui_treasury::treasury::Treasury,
		_arg4: vector<sui::coin::Coin<afsui::afsui::AFSUI>>,
		_arg5: &mut sui::tx_context::TxContext
	): sui::coin::Coin<sui::sui::SUI>
	{
		abort 0
	}

	entry fun request_unstake_vec_atomic_and_keep(
		_arg0: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg1: &safe::safe::Safe<sui::coin::TreasuryCap<afsui::afsui::AFSUI>>,
		_arg2: &afsui_referral_vault::referral_vault::ReferralVault,
		_arg3: &mut afsui_treasury::treasury::Treasury,
		_arg4: vector<sui::coin::Coin<afsui::afsui::AFSUI>>,
		_arg5: &mut sui::tx_context::TxContext
	)
	{
		abort 0
	}

	public fun rotate_operation_cap(
		_arg0: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg1: &mut sui_system::sui_system::SuiSystemState,
		_arg2: &mut sui::tx_context::TxContext
	)
	{
		abort 0
	}

	public fun update_validator_fee(
		_arg0: &lsd::validator::UnverifiedValidatorOperationCap,
		_arg1: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg2: u64
	)
	{
		abort 0
	}

	entry fun create_staked_sui_vault(
		_arg0: lsd::staked_sui_vault::CreateStakedSuiVaultCap,
		_arg1: &mut sui_system::sui_system::SuiSystemState,
		_arg2: address,
		_arg3: u64,
		_arg4: u64,
		_arg5: u64,
		_arg6: u64,
		_arg7: u64,
		_arg8: u64,
		_arg9: u64,
		_arg10: u64,
		_arg11: u64,
		_arg12: u64,
		_arg13: u64,
		_arg14: u64,
		_arg15: u64,
		_arg16: u64,
		_arg17: u64,
		_arg18: u64,
		_arg19: &mut sui::tx_context::TxContext
	)
	{
		abort 0
	}

	public fun authorize(
		_arg0: &safe::safe::OwnerCap,
		_arg1: &lsd::staked_sui_vault::StakedSuiVault,
		_arg2: &mut safe::safe::Safe<sui::coin::TreasuryCap<afsui::afsui::AFSUI>>
	)
	{
		abort 0
	}

	public fun revoke_auth(
		_arg0: &safe::safe::OwnerCap,
		_arg1: &mut safe::safe::Safe<sui::coin::TreasuryCap<afsui::afsui::AFSUI>>
	)
	{
		abort 0
	}

	entry fun migrate(
		_arg0: &lsd::staked_sui_vault::AdminCap,
		_arg1: &mut lsd::staked_sui_vault::StakedSuiVault
	)
	{
		abort 0
	}

	entry fun update_dev_account(
		_arg0: &lsd::staked_sui_vault::AdminCap,
		_arg1: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg2: address
	)
	{
		abort 0
	}

	entry fun update_crank_incentive_reward_per_instruction(
		_arg0: &lsd::staked_sui_vault::AdminCap,
		_arg1: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg2: u64
	)
	{
		abort 0
	}

	entry fun update_max_crank_incentive_reward(
		_arg0: &lsd::staked_sui_vault::AdminCap,
		_arg1: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg2: u64
	)
	{
		abort 0
	}

	entry fun update_reference_gas_price(
		_arg0: &lsd::staked_sui_vault::AdminCap,
		_arg1: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg2: u64
	)
	{
		abort 0
	}

	entry fun update_min_staking_threshold(
		_arg0: &lsd::staked_sui_vault::AdminCap,
		_arg1: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg2: u64
	)
	{
		abort 0
	}

	entry fun update_min_fields_requests_per_tx(
		_arg0: &lsd::staked_sui_vault::AdminCap,
		_arg1: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg2: u64
	)
	{
		abort 0
	}

	entry fun update_pool_rates_epoch_gap(
		_arg0: &lsd::staked_sui_vault::AdminCap,
		_arg1: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg2: u64
	)
	{
		abort 0
	}

	entry fun update_unstaking_bunch_size(
		_arg0: &lsd::staked_sui_vault::AdminCap,
		_arg1: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg2: u64
	)
	{
		abort 0
	}

	entry fun update_default_unstake_total_fee(
		_arg0: &lsd::staked_sui_vault::AdminCap,
		_arg1: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg2: u64
	)
	{
		abort 0
	}

	entry fun update_default_unstake_fee_allocations(
		_arg0: &lsd::staked_sui_vault::AdminCap,
		_arg1: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg2: u64,
		_arg3: u64,
		_arg4: u64
	)
	{
		abort 0
	}

	entry fun update_default_unstake_referee_discount(
		_arg0: &lsd::staked_sui_vault::AdminCap,
		_arg1: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg2: u64
	)
	{
		abort 0
	}

	entry fun update_atomic_unstake_max_fee(
		_arg0: &lsd::staked_sui_vault::AdminCap,
		_arg1: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg2: u64
	)
	{
		abort 0
	}

	entry fun update_atomic_unstake_min_fee(
		_arg0: &lsd::staked_sui_vault::AdminCap,
		_arg1: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg2: u64
	)
	{
		abort 0
	}

	entry fun update_atomic_unstake_fee_allocations(
		_arg0: &lsd::staked_sui_vault::AdminCap,
		_arg1: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg2: u64,
		_arg3: u64,
		_arg4: u64
	)
	{
		abort 0
	}

	entry fun update_atomic_unstake_referee_discount(
		_arg0: &lsd::staked_sui_vault::AdminCap,
		_arg1: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg2: u64
	)
	{
		abort 0
	}

	entry fun update_atomic_unstake_sui_reserves_target_value(
		_arg0: &lsd::staked_sui_vault::AdminCap,
		_arg1: &mut lsd::staked_sui_vault::StakedSuiVault,
		_arg2: u64
	)
	{
		abort 0
	}
}