// Copyright (c) Aftermath Technologies, Inc.
// SPDX-License-Identifier: Apache-2.0

#[allow(unused_field)]
module afterburner_vaults::events {
	struct CreatedVaultEvent has copy, drop {
		vault_id: sui::object::ID,
		stake_type: std::ascii::String,
		min_lock_duration_ms: u64,
		max_lock_duration_ms: u64,
		max_lock_multiplier: u64,
		min_stake_amount: u64
	}

	struct InitializedRewardEvent has copy, drop {
		vault_id: sui::object::ID,
		reward_type: std::ascii::String,
		reward_amount: u64,
		emission_rate: u64,
		emission_start_ms: u64
	}

	struct AddedRewardEvent has copy, drop {
		vault_id: sui::object::ID,
		reward_type: std::ascii::String,
		reward_amount: u64
	}

	struct IncreasedEmissionsEvent has copy, drop {
		vault_id: sui::object::ID,
		reward_type: std::ascii::String,
		emission_schedule_ms: u64,
		emission_rate: u64
	}

	struct StakedEvent has copy, drop {
		staked_position_id: sui::object::ID,
		vault_id: sui::object::ID,
		staked_type: std::ascii::String,
		staked_amount: u64,
		multiplied_staked_amount: u64,
		lock_start_timestamp_ms: u64,
		lock_duration_ms: u64,
		lock_multiplier: u64
	}

	struct StakedEventRelaxed has copy, drop {
		staked_position_id: sui::object::ID,
		vault_id: sui::object::ID,
		staked_type: std::ascii::String,
		staked_amount: u64,
		lock_start_timestamp_ms: u64,
		lock_end_timestamp_ms: u64
	}

	struct LockedEvent has copy, drop {
		staked_position_id: sui::object::ID,
		vault_id: sui::object::ID,
		staked_type: std::ascii::String,
		staked_amount: u64,
		lock_start_timestamp_ms: u64,
		lock_duration_ms: u64,
		lock_multiplier: u64
	}

	struct UnlockedEvent has copy, drop {
		staked_position_id: sui::object::ID,
		vault_id: sui::object::ID,
		staked_type: std::ascii::String,
		staked_amount: u64
	}

	struct JoinedEvent has copy, drop {
		staked_position_id: sui::object::ID,
		other_staked_position_id: sui::object::ID
	}

	struct SplitEvent has copy, drop {
		staked_position_id: sui::object::ID,
		split_staked_position_id: sui::object::ID
	}

	struct DepositedPrincipalEvent has copy, drop {
		staked_position_id: sui::object::ID,
		vault_id: sui::object::ID,
		stake_type: std::ascii::String,
		amount: u64
	}

	struct WithdrewPrincipalEvent has copy, drop {
		staked_position_id: sui::object::ID,
		vault_id: sui::object::ID,
		stake_type: std::ascii::String,
		amount: u64
	}

	struct HarvestedRewardsEvent has copy, drop {
		afterburner_vault_id: sui::object::ID,
		reward_types: vector<std::ascii::String>,
		reward_amounts: vector<u64>
	}

	struct HarvestedRewardsEventMetadata {
		afterburner_vault_id: sui::object::ID,
		reward_types: vector<std::ascii::String>,
		reward_amounts: vector<u64>
	}

	struct DestroyedStakedPositionEvent has copy, drop {
		staked_position_id: sui::object::ID
	}

	public fun afterburner_vault_id(
		_arg0: &afterburner_vaults::events::HarvestedRewardsEventMetadata
	): sui::object::ID
	{
		abort 0
	}
}