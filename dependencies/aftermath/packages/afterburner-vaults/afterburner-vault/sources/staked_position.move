// Copyright (c) Aftermath Technologies, Inc.
// SPDX-License-Identifier: Apache-2.0

#[allow(unused_field, unused_type_parameter)]
module afterburner_vaults::staked_position {
	struct StakedPosition<phantom T0> has store, key {
		id: sui::object::UID,
		afterburner_vault_id: sui::object::ID,
		balance: sui::balance::Balance<T0>,
		multiplier_staked_amount: u64,
		lock_start_timestamp_ms: u64,
		lock_duration_ms: u64,
		lock_multiplier: u64,
		last_reward_timestamp_ms: u64,
		base_rewards_accumulated: vector<u64>,
		multiplier_rewards_accumulated: vector<u64>,
		base_rewards_debt: vector<u64>,
		multiplier_rewards_debt: vector<u64>
	}

	public fun stake<T0>(
		_arg0: &mut afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg1: &sui::clock::Clock,
		_arg2: sui::coin::Coin<T0>,
		_arg3: u64,
		_arg4: &mut sui::tx_context::TxContext
	): afterburner_vaults::staked_position::StakedPosition<T0>
	{
		abort 0
	}

	public fun transfer<T0>(
		_arg0: afterburner_vaults::staked_position::StakedPosition<T0>,
		_arg1: address
	)
	{
		abort 0
	}

	public fun afterburner_vault_id<T0>(
		_arg0: &afterburner_vaults::staked_position::StakedPosition<T0>
	): sui::object::ID
	{
		abort 0
	}

	public fun staked_amount<T0>(
		_arg0: &afterburner_vaults::staked_position::StakedPosition<T0>
	): u64
	{
		abort 0
	}

	public fun multiplier_staked_amount<T0>(
		_arg0: &afterburner_vaults::staked_position::StakedPosition<T0>
	): u64
	{
		abort 0
	}

	public fun staked_amount_with_multiplier<T0>(
		_arg0: &afterburner_vaults::staked_position::StakedPosition<T0>
	): u64
	{
		abort 0
	}

	public fun lock_start_timestamp_ms<T0>(
		_arg0: &afterburner_vaults::staked_position::StakedPosition<T0>
	): u64
	{
		abort 0
	}

	public fun lock_duration_ms<T0>(
		_arg0: &afterburner_vaults::staked_position::StakedPosition<T0>
	): u64
	{
		abort 0
	}

	public fun lock_end_timestamp_ms<T0>(
		_arg0: &afterburner_vaults::staked_position::StakedPosition<T0>
	): u64
	{
		abort 0
	}

	public fun is_unlocked<T0>(
		_arg0: &afterburner_vaults::staked_position::StakedPosition<T0>,
		_arg1: &mut afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg2: &sui::clock::Clock
	): bool
	{
		abort 0
	}

	public fun lock_multiplier<T0>(
		_arg0: &afterburner_vaults::staked_position::StakedPosition<T0>
	): u64
	{
		abort 0
	}

	public fun last_reward_timestamp_ms<T0>(
		_arg0: &afterburner_vaults::staked_position::StakedPosition<T0>
	): u64
	{
		abort 0
	}

	public fun base_rewards_accumulated<T0>(
		_arg0: &afterburner_vaults::staked_position::StakedPosition<T0>
	): vector<u64>
	{
		abort 0
	}

	public fun base_rewards_accumulated_for<T0, T1>(
		_arg0: &afterburner_vaults::staked_position::StakedPosition<T0>,
		_arg1: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): u64
	{
		abort 0
	}

	public fun multiplier_rewards_accumulated<T0>(
		_arg0: &afterburner_vaults::staked_position::StakedPosition<T0>
	): vector<u64>
	{
		abort 0
	}

	public fun multiplier_rewards_accumulated_for<T0, T1>(
		_arg0: &afterburner_vaults::staked_position::StakedPosition<T0>,
		_arg1: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): u64
	{
		abort 0
	}

	public fun base_rewards_debt<T0>(
		_arg0: &afterburner_vaults::staked_position::StakedPosition<T0>
	): vector<u64>
	{
		abort 0
	}

	public fun base_rewards_debt_for<T0, T1>(
		_arg0: &afterburner_vaults::staked_position::StakedPosition<T0>,
		_arg1: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): u64
	{
		abort 0
	}

	public fun multiplier_rewards_debt<T0>(
		_arg0: &afterburner_vaults::staked_position::StakedPosition<T0>
	): vector<u64>
	{
		abort 0
	}

	public fun multiplier_rewards_debt_for<T0, T1>(
		_arg0: &afterburner_vaults::staked_position::StakedPosition<T0>,
		_arg1: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): u64
	{
		abort 0
	}

	public fun update_position<T0>(
		_arg0: &mut afterburner_vaults::staked_position::StakedPosition<T0>,
		_arg1: &mut afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg2: &sui::clock::Clock
	)
	{
		abort 0
	}

	public fun begin_harvest<T0>(
		_arg0: &afterburner_vaults::afterburner_vault::AfterburnerVault<T0>
	): afterburner_vaults::events::HarvestedRewardsEventMetadata
	{
		abort 0
	}

	public fun harvest_rewards<T0, T1>(
		_arg0: &mut afterburner_vaults::staked_position::StakedPosition<T0>,
		_arg1: &mut afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg2: &mut afterburner_vaults::events::HarvestedRewardsEventMetadata,
		_arg3: &sui::clock::Clock,
		_arg4: &mut sui::tx_context::TxContext
	): sui::coin::Coin<T1>
	{
		abort 0
	}

	public fun end_harvest(
		_arg0: afterburner_vaults::events::HarvestedRewardsEventMetadata
	)
	{
		abort 0
	}

	public fun deposit_principal<T0>(
		_arg0: &mut afterburner_vaults::staked_position::StakedPosition<T0>,
		_arg1: &mut afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg2: &sui::clock::Clock,
		_arg3: sui::coin::Coin<T0>
	)
	{
		abort 0
	}

	public fun withdraw_principal<T0>(
		_arg0: &mut afterburner_vaults::staked_position::StakedPosition<T0>,
		_arg1: &mut afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg2: &sui::clock::Clock,
		_arg3: u64,
		_arg4: &mut sui::tx_context::TxContext
	): sui::coin::Coin<T0>
	{
		abort 0
	}

	public fun lock<T0>(
		_arg0: &mut afterburner_vaults::staked_position::StakedPosition<T0>,
		_arg1: &mut afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg2: &sui::clock::Clock,
		_arg3: u64
	)
	{
		abort 0
	}

	public fun renew_lock<T0>(
		_arg0: &mut afterburner_vaults::staked_position::StakedPosition<T0>,
		_arg1: &mut afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg2: &sui::clock::Clock
	)
	{
		abort 0
	}

	public fun unlock<T0>(
		_arg0: &mut afterburner_vaults::staked_position::StakedPosition<T0>,
		_arg1: &mut afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg2: &sui::clock::Clock
	)
	{
		abort 0
	}

	public fun join<T0>(
		_arg0: &mut afterburner_vaults::staked_position::StakedPosition<T0>,
		_arg1: afterburner_vaults::staked_position::StakedPosition<T0>,
		_arg2: &mut afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg3: &sui::clock::Clock
	)
	{
		abort 0
	}

	public fun split<T0>(
		_arg0: &mut afterburner_vaults::staked_position::StakedPosition<T0>,
		_arg1: &mut afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg2: &sui::clock::Clock,
		_arg3: u64,
		_arg4: &mut sui::tx_context::TxContext
	): afterburner_vaults::staked_position::StakedPosition<T0>
	{
		abort 0
	}

	public fun destroy<T0>(
		_arg0: afterburner_vaults::staked_position::StakedPosition<T0>,
		_arg1: &mut afterburner_vaults::afterburner_vault::AfterburnerVault<T0>,
		_arg2: &sui::clock::Clock
	)
	{
		abort 0
	}
}