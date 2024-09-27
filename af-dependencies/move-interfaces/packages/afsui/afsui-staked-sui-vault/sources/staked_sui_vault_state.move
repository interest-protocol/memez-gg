// Copyright (c) Aftermath Technologies, Inc.
// SPDX-License-Identifier: Apache-2.0

module lsd::staked_sui_vault_state {
	struct DefaultUnstakeProtocolFeeConfig has store {
		total_fee: u64,
		treasury_allocation: u64,
		dev_wallet_allocation: u64,
		crank_incentive_allocation: u64,
		referee_discount: u64
	}

	struct AtomicUnstakeProtocolFeeConfig has store {
		max_fee: u64,
		min_fee: u64,
		treasury_allocation: u64,
		dev_wallet_allocation: u64,
		crank_incentive_allocation: u64,
		referee_discount: u64
	}

	struct ProtocolConfig has store {
		max_validator_fee: u64,
		dev_account: address,
		default_unstake_protocol_fee: lsd::staked_sui_vault_state::DefaultUnstakeProtocolFeeConfig,
		atomic_unstake_protocol_fee: lsd::staked_sui_vault_state::AtomicUnstakeProtocolFeeConfig,
		atomic_unstake_sui_reserves_target_value: u64,
		min_staking_threshold: u64,
		crank_incentive_reward_per_instruction: u64,
		max_crank_incentive_reward: u64,
		reference_gas_price: u64,
		min_fields_requests_per_tx: u64,
		pool_rates_epoch_gap: u64,
		unstaking_bunch_size: u64
	}

	struct ValidatorConfig has store {
		sui_address: address,
		operation_cap_id: sui::object::ID,
		fee: u64
	}

	struct EpochWasChangedState has store {
		is_epoch_processing: bool,
		is_inactive_stakes_processed: bool,
		is_unstaking_deque_sorted: bool,
		is_total_sui_amount_updated: bool,
		is_unstaking_from_storage_processed: bool,
		is_pending_unstakes_processed: bool,
		amount_to_unstake: u64,
		reserves_before_unstake: u64
	}

	struct StakedSuiVaultStateV1 has store, key {
		id: sui::object::UID,
		protocol_config: lsd::staked_sui_vault_state::ProtocolConfig,
		validator_configs: sui::linked_table::LinkedTable<address, lsd::staked_sui_vault_state::ValidatorConfig>,
		staked_sui_storage: lsd::storage::Storage,
		crank_incentive_reward_pool: sui::balance::Balance<sui::sui::SUI>,
		sui_reserves: sui::balance::Balance<sui::sui::SUI>,
		atomic_unstake_sui_reserves: sui::balance::Balance<sui::sui::SUI>,
		afsui_bin: sui::balance::Balance<afsui::afsui::AFSUI>,
		pending_unstake_records: sui::table_vec::TableVec<lsd::record::PendingUnstakeRecord>,
		inactive_stakes: sui::table_vec::TableVec<sui_system::staking_pool::StakedSui>,
		active_epoch: u64,
		epoch_was_changed_state: lsd::staked_sui_vault_state::EpochWasChangedState,
		total_sui_amount: u64,
		total_rewards_amount: u64
	}

}