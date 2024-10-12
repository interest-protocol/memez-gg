// Copyright (c) Aftermath Technologies, Inc.
// SPDX-License-Identifier: Apache-2.0

#[allow(unused_field, unused_type_parameter)]
module afterburner_vaults::afterburner_vault {
	struct OwnerCap has store, key {
		id: sui::object::UID,
		afterburner_vault_id: sui::object::ID
	}

	struct OneTimeAdminCap<phantom T0> has store, key {
		id: sui::object::UID,
		afterburner_vault_id: sui::object::ID
	}

	struct AfterburnerVault<phantom T0> has store, key {
		id: sui::object::UID,
		type_names: vector<std::ascii::String>,
		rewards: vector<u64>,
		rewards_accumulated_per_share: vector<u128>,
		total_staked_amount: u64,
		total_staked_amount_with_multiplier: u64,
		emission_schedules_ms: vector<u64>,
		emission_rates: vector<u64>,
		emission_start_timestamps_ms: vector<u64>,
		emission_end_timestamp_ms: u64,
		last_reward_timestamps_ms: vector<u64>,
		lock_enforcement: u64,
		min_lock_duration_ms: u64,
		max_lock_duration_ms: u64,
		max_lock_multiplier: u64,
		min_stake_amount: u64
	}

	struct UnlockFlag has copy, drop, store {
		dummy_field: bool
	}

	public fun new<T0>(
		_arg0: u64,
		_arg1: u64,
		_arg2: u64,
		_arg3: u64,
		_arg4: u64,
		_arg5: &mut sui::tx_context::TxContext
	): (afterburner_vaults::afterburner_vault::AfterburnerVault<T0>, afterburner_vaults::afterburner_vault::OwnerCap)
	{
		abort 0
	}

	public fun share_vault<T0>(
		_arg0: afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	)
	{
		abort 0
	}

	public fun transfer_owner_cap(
		_arg0: afterburner_vaults::afterburner_vault::OwnerCap,
		_arg1: address
	)
	{
		abort 0
	}

	public fun type_names<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): vector<std::ascii::String>
	{
		abort 0
	}

	public fun type_names_len<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): u64
	{
		abort 0
	}

	public fun contains_type_name<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg1: std::ascii::String
	): bool
	{
		abort 0
	}

	public fun contains_type<T0, T1>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): bool
	{
		abort 0
	}

	public fun type_name_to_index<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg1: std::ascii::String
	): u64
	{
		abort 0
	}

	public fun type_to_index<T0, T1>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): u64
	{
		abort 0
	}

	public fun rewards<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): vector<u64>
	{
		abort 0
	}

	public fun rewards_of<T0, T1>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): u64
	{
		abort 0
	}

	public fun rewards_accumulated_per_share<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): vector<u128>
	{
		abort 0
	}

	public fun rewards_accumulated_per_share_for<T0, T1>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): u128
	{
		abort 0
	}

	public fun total_staked_amount<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): u64
	{
		abort 0
	}

	public fun total_staked_amount_with_multiplier<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): u64
	{
		abort 0
	}

	public fun emission_schedules_ms<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): vector<u64>
	{
		abort 0
	}

	public fun emission_schedule_ms_for<T0, T1>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): u64
	{
		abort 0
	}

	public fun emission_rates<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): vector<u64>
	{
		abort 0
	}

	public fun emission_rate_for<T0, T1>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): u64
	{
		abort 0
	}

	public fun emission_start_timestamps_ms<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): vector<u64>
	{
		abort 0
	}

	public fun emission_start_timestamp_ms_for<T0, T1>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): u64
	{
		abort 0
	}

	public fun emission_end_timestamp_ms<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): u64
	{
		abort 0
	}

	public fun last_reward_timestamps_ms<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): vector<u64>
	{
		abort 0
	}

	public fun last_reward_timestamp_ms_for<T0, T1>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): u64
	{
		abort 0
	}

	public fun lock_enforcement<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): u64
	{
		abort 0
	}

	public fun min_lock_duration_ms<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): u64
	{
		abort 0
	}

	public fun max_lock_duration_ms<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): u64
	{
		abort 0
	}

	public fun max_lock_multiplier<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): u64
	{
		abort 0
	}

	public fun calc_lock_multiplier<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg1: u64
	): u64
	{
		abort 0
	}

	public fun min_stake_amount<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): u64
	{
		abort 0
	}

	public fun calc_rewards_debt<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg1: u64
	): vector<u64>
	{
		abort 0
	}

	public fun calc_emitted_rewards<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): vector<u64>
	{
		abort 0
	}

	public fun calc_emitted_rewards_for<T0, T1>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): u64
	{
		abort 0
	}

	public fun minimal_claim(
		
	): u64
	{
		abort 0
	}

	public fun is_vault_unlocked<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): bool
	{
		abort 0
	}

	public fun remaining_rewards<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): vector<u64>
	{
		abort 0
	}

	public fun remaining_rewards_for<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg1: u64
	): u64
	{
		abort 0
	}

	public fun emit_rewards<T0>(
		_arg0: &mut afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg1: &sui::clock::Clock
	)
	{
		abort 0
	}

	public(friend) fun increase_stake<T0>(
		_arg0: &mut afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg1: u64
	)
	{
		abort 0
	}

	public fun set_emission_end_timestamp_ms<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::OwnerCap,
		_arg1: &mut afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg2: u64
	)
	{
		abort 0
	}

	public fun add_remaining_rewards<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::OwnerCap,
		_arg1: &mut afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg2: vector<u64>
	)
	{
		abort 0
	}

	public fun set_remaining_rewards<T0, T1>(
		_arg0: &afterburner_vaults::afterburner_vault::OwnerCap,
		_arg1: &mut afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg2: u64
	)
	{
		abort 0
	}

	public fun initialize_reward<T0, T1>(
		_arg0: &afterburner_vaults::afterburner_vault::OwnerCap,
		_arg1: &mut afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg2: &sui::clock::Clock,
		_arg3: sui::coin::Coin<T1>,
		_arg4: u64,
		_arg5: u64,
		_arg6: u64
	)
	{
		abort 0
	}

	public fun add_reward<T0, T1>(
		_arg0: &afterburner_vaults::afterburner_vault::OwnerCap,
		_arg1: &mut afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg2: sui::coin::Coin<T1>
	)
	{
		abort 0
	}

	public fun increase_emissions_for<T0, T1>(
		_arg0: &afterburner_vaults::afterburner_vault::OwnerCap,
		_arg1: &mut afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg2: u64,
		_arg3: u64
	)
	{
		abort 0
	}

	public fun update_emissions_for<T0, T1>(
		_arg0: &afterburner_vaults::afterburner_vault::OwnerCap,
		_arg1: &mut afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg2: &sui::clock::Clock,
		_arg3: u64,
		_arg4: u64
	)
	{
		abort 0
	}

	public fun grant_one_time_admin_cap<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::OwnerCap,
		_arg1: address,
		_arg2: &mut sui::tx_context::TxContext
	)
	{
		abort 0
	}

	public fun unlock_vault<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::OwnerCap,
		_arg1: &mut afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	)
	{
		abort 0
	}

	public fun lock_vault<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::OwnerCap,
		_arg1: &mut afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	)
	{
		abort 0
	}

	public fun initialize_reward_and_consume_admin_cap<T0, T1>(
		_arg0: afterburner_vaults::afterburner_vault::OneTimeAdminCap<T1>,
		_arg1: &mut afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg2: &sui::clock::Clock,
		_arg3: sui::coin::Coin<T1>,
		_arg4: u64,
		_arg5: u64,
		_arg6: u64
	)
	{
		abort 0
	}

	public fun add_reward_and_consume_admin_cap<T0, T1>(
		_arg0: afterburner_vaults::afterburner_vault::OneTimeAdminCap<T1>,
		_arg1: &mut afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg2: sui::coin::Coin<T1>
	)
	{
		abort 0
	}
}