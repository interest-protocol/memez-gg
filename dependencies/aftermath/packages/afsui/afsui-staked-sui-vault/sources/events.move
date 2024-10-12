// Copyright (c) Aftermath Technologies, Inc.
// SPDX-License-Identifier: Apache-2.0

module lsd::events {
	struct CreatedStakedSuiVaultEvent has copy, drop {
		staking_entity_id: sui::object::ID
	}

	struct StakedEvent has copy, drop {
		staker: address,
		validator: address,
		staked_sui_id: sui::object::ID,
		sui_id: sui::object::ID,
		sui_amount: u64,
		afsui_id: sui::object::ID,
		afsui_amount: u64,
		validator_fee: u64,
		referrer: std::option::Option<address>,
		epoch: u64,
		is_restaked: bool
	}

	struct UnstakeRequestedEvent has copy, drop {
		afsui_id: sui::object::ID,
		provided_afsui_amount: u64,
		requester: address,
		epoch: u64
	}

	struct UnstakedEvent has copy, drop {
		afsui_id: sui::object::ID,
		provided_afsui_amount: u64,
		sui_id: sui::object::ID,
		returned_sui_amount: u64,
		requester: std::option::Option<address>,
		epoch: u64
	}

	struct OneRoundOfEpochProcessingFinished has copy, drop {
		staking_entity_id: sui::object::ID,
		epoch: u64,
		is_epoch_processing: bool,
		is_pending_unstakes_processed: bool,
		is_unstaking_deque_sorted: bool
	}

	struct EpochWasChangedEvent has copy, drop {
		active_epoch: u64,
		total_sui_amount: u64,
		total_rewards_amount: u64,
		total_afsui_supply: u64
	}
}